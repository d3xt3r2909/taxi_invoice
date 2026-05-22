from __future__ import annotations

import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from tools.ai import cli
from tools.ai.core import (
    _extract_variants,
    _load_fragments,
    _load_platforms,
    _load_scopes,
    _load_skills,
    _load_targets,
    _load_yaml_file,
    enabled_platform_ids,
    fragment_sources,
    load_model,
    normalize_repo_path,
    parse_markdown_frontmatter,
    render_included_fragments,
    repo_relative,
)
from tools.ai.model import (
    Fragment,
    GeneratedFile,
    PlatformConfig,
    Scope,
    Skill,
    SourceModel,
    TargetAssembly,
    TargetOutput,
)
from tools.ai.plugins.agents import AgentsPlugin
from tools.ai.plugins.base import BasePlugin
from tools.ai.plugins.claude import ClaudePlugin
from tools.ai.plugins.codex_skills import CodexSkillsPlugin
from tools.ai.plugins.copilot import CopilotPlugin
from tools.ai.plugins.copilot_review import CopilotReviewPlugin
from tools.ai.plugins.cursor import CursorPlugin
from tools.ai.render import (
    TRACE_TEXT,
    line_comment_trace,
    render_markdown_output,
    render_skill_files,
    resource_trace_content,
    yaml_comment_trace,
)
from tools.ai.validate import (
    collect_drift,
    collect_output_errors,
    collect_ownership_errors,
    collect_source_errors,
    instantiate_plugins,
    output_for_path,
    output_inventory,
    render_all,
)
from tools.ai.yaml_util import YamlError, _parse_block, dump_yaml, parse_yaml


REPO_ROOT = Path(__file__).resolve().parents[3]


class AiInstructionCompilerTest(unittest.TestCase):
    def test_mvp_outputs_are_rendered(self) -> None:
        outputs = self._render_outputs()
        rendered_paths = {output.path.as_posix() for output in outputs}

        self.assertIn("AGENTS.md", rendered_paths)
        self.assertIn(".github/copilot-instructions.md", rendered_paths)
        self.assertIn(".cursor/rules/ai/project.mdc", rendered_paths)
        self.assertIn(".cursor/rules/ai/review.mdc", rendered_paths)
        self.assertIn(".cursor/skills/ai-instructions/SKILL.md", rendered_paths)
        self.assertIn(".cursor/skills/app-coding-rules/SKILL.md", rendered_paths)
        self.assertIn(".cursor/skills/pr-review/SKILL.md", rendered_paths)
        self.assertIn(
            ".github/instructions/ai-review/review.instructions.md",
            rendered_paths,
        )
        self.assertIn("CLAUDE.md", rendered_paths)
        self.assertIn(".claude/skills/ai-instructions/SKILL.md", rendered_paths)
        self.assertIn(".claude/skills/pr-review/SKILL.md", rendered_paths)
        self.assertIn(".agents/skills/ai-instructions/SKILL.md", rendered_paths)
        self.assertIn(
            ".agents/skills/ai-instructions/agents/openai.yaml",
            rendered_paths,
        )
        self.assertIn(".agents/skills/app-coding-rules/SKILL.md", rendered_paths)
        self.assertIn(".agents/skills/pr-review/SKILL.md", rendered_paths)
        self.assertIn(".agents/skills/pr-review/agents/openai.yaml", rendered_paths)

    def test_copilot_review_output_stays_within_budget(self) -> None:
        outputs = self._render_outputs()
        copilot_output = next(
            output
            for output in outputs
            if output.path.as_posix()
            == ".github/instructions/ai-review/review.instructions.md"
        )

        self.assertLessEqual(
            len(copilot_output.content),
            int(copilot_output.limits["max_chars"]),
        )

    def test_skill_outputs_share_the_same_source_ids(self) -> None:
        outputs = self._render_outputs()
        codex_skill = next(
            output
            for output in outputs
            if output.path.as_posix() == ".agents/skills/pr-review/SKILL.md"
        )
        claude_skill = next(
            output
            for output in outputs
            if output.path.as_posix() == ".claude/skills/pr-review/SKILL.md"
        )
        cursor_skill = next(
            output
            for output in outputs
            if output.path.as_posix() == ".cursor/skills/pr-review/SKILL.md"
        )

        self.assertEqual(codex_skill.source_ids, claude_skill.source_ids)
        self.assertEqual(codex_skill.source_ids, cursor_skill.source_ids)

    def test_drift_detects_extra_files_inside_owned_dirs(self) -> None:
        with TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            owned_dir = repo_root / "owned"
            owned_dir.mkdir()
            generated_file = owned_dir / "generated.md"
            generated_file.write_text("expected\n")
            (owned_dir / "manual.md").write_text("manual\n")
            model = SourceModel(
                repo_root=repo_root,
                config={},
                scopes={},
                fragments={},
                platforms={
                    "test": PlatformConfig(
                        id="test",
                        display_name="Test",
                        plugin="test",
                        path=Path("ai/platforms/test.yml"),
                        owned_exact_dirs=[Path("owned")],
                        owned_exact_files=[],
                        limits={},
                        requirements={},
                    )
                },
                targets={},
                skills={},
            )
            output = GeneratedFile(
                path=Path("owned/generated.md"),
                content="expected\n",
                platform="test",
                source_ids=("ai/targets/test.yml",),
                logical_target=Path("owned/generated.md"),
            )

            stale, extra = collect_drift(model, [output])

        self.assertEqual(stale, [])
        self.assertEqual(extra, ["owned/manual.md"])

    def test_core_helpers_cover_fallbacks_and_variant_errors(self) -> None:
        with TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            outside = Path(temp_dir).parent / "outside.md"
            no_frontmatter = repo_root / "plain.md"
            no_frontmatter.write_text("body\n")
            list_frontmatter = repo_root / "list.md"
            list_frontmatter.write_text("---\n- value\n---\nbody\n")
            errors: list[str] = []

            metadata, body = parse_markdown_frontmatter(no_frontmatter)
            list_metadata, list_body = parse_markdown_frontmatter(list_frontmatter)
            variants = _extract_variants(
                no_frontmatter,
                {"variants": {"standard": True, "missing": True}},
                "# Standard\nBody\n",
                errors,
            )

            self.assertEqual(repo_relative(repo_root, outside), outside.as_posix())
            self.assertEqual(normalize_repo_path("a/b"), Path("a/b"))
            self.assertEqual(normalize_repo_path(r"a\b"), Path("a/b"))
            self.assertEqual(enabled_platform_ids(self._model(config={"enabled_platforms": "bad"})), [])
            self.assertEqual(metadata, {})
            self.assertEqual(body, "body\n")
            self.assertEqual(list_metadata, {})
            self.assertEqual(list_body, "body\n")
            self.assertEqual(variants, {"standard": "Body\n"})
            self.assertIn("declared variant missing has no matching heading", errors[0])
            self.assertEqual(
                _extract_variants(
                    no_frontmatter,
                    {"variants": {"standard": True}},
                    "Plain body\n",
                    [],
                ),
                {"standard": "Plain body\n"},
            )
            self.assertEqual(_extract_variants(no_frontmatter, {"variants": []}, "body\n", []), {})

    def test_core_loaders_report_malformed_source_files(self) -> None:
        with TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            missing = root / "missing"
            bad_yaml = root / "bad.yml"
            bad_yaml.write_text("\tbad: value\n")
            scopes = root / "scopes.yml"
            scopes.write_text("scopes:\n  bad: value\n")
            scopes_not_mapping = root / "scopes-not-mapping.yml"
            scopes_not_mapping.write_text("scopes: bad\n")
            fragments = root / "fragments"
            fragments.mkdir()
            (fragments / "a.md").write_text("---\nid: duplicate\nvariants:\n  standard: true\n---\n# Standard\nA\n")
            (fragments / "b.md").write_text("---\nid: duplicate\n---\n# Standard\nB\n")
            (fragments / "bad.md").write_text("---\n\tbad: value\n---\nBody\n")
            platforms = root / "platforms"
            platforms.mkdir()
            (platforms / "bad.yml").write_text("- value\n")
            (platforms / "fallback.yml").write_text("owned: bad\nlimits: bad\nrequirements: bad\n")
            (platforms / "owned-bad.yml").write_text(
                "owned:\n"
                "  exact_dirs: bad\n"
                "  exact_files: bad\n"
            )
            (platforms / "paths.yml").write_text(
                "id: paths\n"
                "owned:\n"
                "  exact_dirs:\n"
                r"    - windows\dir" "\n"
                "  exact_files:\n"
                r"    - windows\file.md" "\n"
            )
            targets = root / "targets"
            targets.mkdir()
            (targets / "bad.yml").write_text("- value\n")
            (targets / "mixed.yml").write_text(
                "outputs:\n"
                "  - bad\n"
                "  - id:\n"
                "    include: bad\n"
                "  - target: missing-id.md\n"
                "  - id: windows\n"
                r"    target: windows\file.md" "\n"
                "  - id: output\n"
                "    target: file.md\n"
                "    frontmatter: bad\n"
                "    limits: bad\n"
                "    include_imports: bad\n"
                "    include:\n"
                "      - bad\n"
            )
            (targets / "not-list.yml").write_text("outputs: bad\n")
            skills = root / "skills"
            skills.mkdir()
            bad_skill = skills / "bad"
            bad_skill.mkdir()
            (bad_skill / "skill.yml").write_text("- value\n")
            duplicate_a = skills / "duplicate-a"
            duplicate_a.mkdir()
            (duplicate_a / "skill.yml").write_text("id: duplicate\nsource: bad\nresources: bad\n")
            duplicate_b = skills / "duplicate-b"
            duplicate_b.mkdir()
            (duplicate_b / "skill.yml").write_text("id: duplicate\n")
            resource_bad = skills / "resource-bad"
            resource_bad.mkdir()
            (resource_bad / "skill.yml").write_text(
                "resources:\n"
                "  references: refs.md\n"
                "  scripts: script.sh\n"
            )
            path_skill = skills / "path-skill"
            path_skill.mkdir()
            (path_skill / "skill.yml").write_text(
                "id: paths\n"
                "source:\n"
                r"  instructions: nested\instructions.md" "\n"
                "resources:\n"
                "  references:\n"
                r"    - refs\one.md" "\n"
                "  scripts:\n"
                r"    - scripts\run.sh" "\n"
            )

            errors: list[str] = []
            self.assertEqual(_load_yaml_file(missing / "none.yml", errors), {})
            self.assertEqual(_load_yaml_file(bad_yaml, errors), {})
            self.assertEqual(_load_scopes(scopes, errors), {})
            self.assertEqual(_load_scopes(scopes_not_mapping, errors), {})
            self.assertEqual(_load_scopes(missing / "scopes.yml", errors), {})
            self.assertIn("directory is missing", _load_fragments(missing, errors) or errors[-1])
            self.assertIn("directory is missing", _load_platforms(missing, errors) or errors[-1])
            self.assertIn("directory is missing", _load_targets(missing, errors) or errors[-1])
            self.assertEqual(_load_skills(missing, errors), {})

            loaded_fragments = _load_fragments(fragments, errors)
            loaded_platforms = _load_platforms(platforms, errors)
            loaded_targets = _load_targets(targets, errors)
            loaded_skills = _load_skills(skills, errors)

            self.assertIn("duplicate", loaded_fragments)
            self.assertIn("fallback", loaded_platforms)
            self.assertIn(Path("windows/dir"), loaded_platforms["paths"].owned_exact_dirs)
            self.assertIn(Path("windows/file.md"), loaded_platforms["paths"].owned_exact_files)
            self.assertIn("mixed", loaded_targets)
            self.assertIn("duplicate", loaded_skills)
            self.assertIn("paths", loaded_skills)
            mixed_output = loaded_targets["mixed"].outputs[-1]
            missing_id_output = next(
                output
                for output in loaded_targets["mixed"].outputs
                if output.path == Path("missing-id.md")
            )
            windows_output = next(
                output
                for output in loaded_targets["mixed"].outputs
                if output.id == "windows"
            )
            self.assertEqual(missing_id_output.id, "")
            self.assertEqual(windows_output.path, Path("windows/file.md"))
            self.assertEqual(
                loaded_skills["paths"].instructions_path,
                path_skill / "nested" / "instructions.md",
            )
            self.assertEqual(
                loaded_skills["paths"].reference_paths,
                [path_skill / "refs" / "one.md"],
            )
            self.assertEqual(
                loaded_skills["paths"].script_paths,
                [path_skill / "scripts" / "run.sh"],
            )
            self.assertEqual(mixed_output.frontmatter, {})
            self.assertEqual(mixed_output.limits, {})
            self.assertEqual(mixed_output.include_imports, [])
            self.assertTrue(any("file is missing" in error for error in errors))
            self.assertTrue(any("tabs are not supported" in error for error in errors))
            self.assertTrue(any("scopes must be a mapping" in error for error in errors))
            self.assertTrue(any("scope bad must be a mapping" in error for error in errors))
            self.assertTrue(any("duplicate fragment id duplicate" in error for error in errors))
            self.assertTrue(any("platform config must be a mapping" in error for error in errors))
            self.assertTrue(any("owned.exact_dirs must be a list" in error for error in errors))
            self.assertTrue(any("owned.exact_files must be a list" in error for error in errors))
            self.assertTrue(any("target assembly must be a mapping" in error for error in errors))
            self.assertTrue(any("outputs must be a list" in error for error in errors))
            self.assertTrue(any("each output must be a mapping" in error for error in errors))
            self.assertTrue(any("include entries must be mappings" in error for error in errors))
            self.assertTrue(any("skill metadata must be a mapping" in error for error in errors))
            self.assertTrue(any("resources.references must be a list" in error for error in errors))
            self.assertTrue(any("resources.scripts must be a list" in error for error in errors))
            self.assertTrue(any("duplicate skill id duplicate" in error for error in errors))

    def test_yaml_parser_and_dumper_cover_supported_shapes_and_errors(self) -> None:
        self.assertEqual(parse_yaml("", source="empty"), {})
        self.assertEqual(parse_yaml("key:\nnext: value\n", source="empty-child"), {"key": {}, "next": "value"})
        self.assertEqual(parse_yaml("items:\n  -\n    name: a\n  -\n", source="list"), {"items": [{"name": "a"}, None]})
        self.assertEqual(
            parse_yaml(
                "items:\n"
                "  - name:\n"
                "      nested: true\n"
                "    count: 2\n"
                "  - {}\n"
                "  - plain\n"
                "  - null\n",
                source="nested",
            ),
            {
                "items": [
                    {"name": {"nested": True}, "count": 2},
                    {},
                    "plain",
                    None,
                ]
            },
        )
        self.assertEqual(
            parse_yaml("items:\n  - name:\n  - other: value\n", source="empty-list-child"),
            {"items": [{"name": {}}, {"other": "value"}]},
        )
        self.assertEqual(parse_yaml("value: '{}'\n", source="quoted"), {"value": "{}"})
        self.assertEqual(parse_yaml("value: {}\nnone: None\n", source="scalars"), {"value": {}, "none": None})
        self.assertEqual(parse_yaml("value: 'unterminated\n", source="quoted"), {"value": "'unterminated"})
        self.assertEqual(
            dump_yaml(
                {
                    "empty_list": [],
                    "empty_map": {},
                    "items": [
                        {},
                        {"name": "a", "enabled": True},
                        {"nested": {"value": False}, "rest": "x"},
                        ["child"],
                    ],
                    "none": None,
                    "count": 3,
                }
            ),
            (
                'empty_list: []\n'
                'empty_map: {}\n'
                'items:\n'
                '  - {}\n'
                '  - name: "a"\n'
                '    enabled: true\n'
                '  - nested:\n'
                '      value: false\n'
                '    rest: "x"\n'
                '  -\n'
                '    - "child"\n'
                'none: null\n'
                'count: 3\n'
            ),
        )
        self.assertEqual(dump_yaml("value"), '"value"\n')

        invalid_inputs = [
            "\tkey: value\n",
            "key:\n  child: value\n  - bad\n",
            "- value\nkey: value\n",
            "key\n",
            ": value\n",
        ]
        for text in invalid_inputs:
            with self.subTest(text=text), self.assertRaises(YamlError):
                parse_yaml(text, source="bad")
        self.assertEqual(_parse_block([], 0, 0, "empty"), ({}, 0))
        self.assertEqual(_parse_block([(0, "key: value", 1)], 0, 2, "low"), ({}, 0))
        with self.assertRaises(YamlError):
            _parse_block([(2, "key: value", 1)], 0, 0, "bad")

    def test_render_helpers_cover_metadata_and_resource_variants(self) -> None:
        with TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            skill_root = repo_root / "ai" / "skills" / "sample"
            skill_root.mkdir(parents=True)
            (skill_root / "instructions.md").write_text("# Sample\n")
            (skill_root / "data.yaml").write_text("value: true\n")
            (skill_root / "plain.txt").write_text("plain\n")
            missing = skill_root / "missing.md"
            skill = Skill(
                id="sample",
                name="sample",
                path=skill_root,
                metadata={
                    "title": "Sample",
                    "description": "Sample skill",
                    "frontmatter": "bad",
                    "openai": "bad",
                },
                instructions_path=skill_root / "missing-instructions.md",
                reference_paths=[skill_root / "data.yaml", skill_root / "plain.txt", missing],
                script_paths=[],
            )
            model = self._model(repo_root=repo_root, skills={"sample": skill})
            output = TargetOutput(
                id="plain",
                platform="test",
                path=Path("plain.md"),
                source_path=Path("ai/targets/test.yml"),
                scope="root",
                title="",
                frontmatter={},
                limits={},
                include=[],
                include_imports=[],
                allow_draft=False,
            )

            markdown = render_markdown_output(model, output, platform="test")
            files = render_skill_files(
                model,
                skill,
                platform="test",
                target_dir=Path(".test/skills/sample"),
                include_openai_metadata=True,
                include_claude_metadata=False,
            )

            self.assertIn("# plain", markdown.content)
            self.assertEqual(skill.title, "Sample")
            openai_file = next(file for file in files if file.path.as_posix().endswith("agents/openai.yaml"))
            self.assertIn("display_name: \"\"", openai_file.content)
            self.assertIn(yaml_comment_trace("test", Path("data.yaml"), ()).splitlines()[0], files[1].content)
            self.assertIn(line_comment_trace("test", Path("plain.txt"), ()).splitlines()[0], files[2].content)
            self.assertIn("Target: .test/skills/sample/missing.md", files[3].content)
            self.assertIn("SKILL.md", files[-1].content)
            self.assertEqual(
                resource_trace_content("test", Path("script.js"), (), "body\n"),
                line_comment_trace("test", Path("script.js"), ()) + "body\n",
            )

    def test_validation_reports_source_output_ownership_and_lookup_errors(self) -> None:
        repo_root = Path("/repo")
        fragment = Fragment(
            id="fragment",
            path=Path("ai/fragments/fragment.md"),
            metadata={"status": "weird", "targets": "bad"},
            variants={"standard": "content\n"},
        )
        draft = Fragment(
            id="draft",
            path=Path("ai/fragments/draft.md"),
            metadata={
                "id": "draft",
                "kind": "rule",
                "title": "Draft",
                "owner": "ai",
                "status": "draft",
                "targets": ["missing"],
            },
            variants={"standard": "draft\n"},
        )
        unreachable = Fragment(
            id="unreachable",
            path=Path("ai/fragments/unreachable.md"),
            metadata={
                "id": "unreachable",
                "kind": "rule",
                "title": "Unreachable",
                "owner": "ai",
                "status": "active",
                "targets": [],
            },
            variants={"standard": "content\n"},
        )
        target = TargetOutput(
            id="",
            platform="missing-target",
            path=Path("."),
            source_path=Path("ai/targets/missing-target.yml"),
            scope="missing",
            title="",
            frontmatter={},
            limits={},
            include=[],
            include_imports=[],
            allow_draft=False,
        )
        draft_target = TargetOutput(
            id="draft-output",
            platform="known",
            path=Path("draft.md"),
            source_path=Path("ai/targets/known.yml"),
            scope="root",
            title="Draft",
            frontmatter={},
            limits={},
            include=[self._fragment_ref("draft", "missing"), self._fragment_ref("unknown", "standard")],
            include_imports=[],
            allow_draft=False,
        )
        skill = Skill(
            id="skill",
            name="skill",
            path=Path("ai/skills/skill"),
            metadata={"status": "bad", "targets": ["missing"]},
            instructions_path=Path("ai/skills/skill/instructions.md"),
            reference_paths=[],
            script_paths=[],
        )
        scalar_targets_skill = Skill(
            id="scalar",
            name="scalar",
            path=Path("ai/skills/scalar"),
            metadata={"status": "active", "targets": "bad"},
            instructions_path=Path("ai/skills/scalar/instructions.md"),
            reference_paths=[],
            script_paths=[],
        )
        model = self._model(
            repo_root=repo_root,
            config={"enabled_platforms": ["known", "unknown-enabled"]},
            platforms={"known": self._platform("known")},
            fragments={"fragment": fragment, "draft": draft, "unreachable": unreachable},
            targets={
                "missing-target": TargetAssembly("missing-target", Path("ai/targets/missing-target.yml"), [target]),
                "known": TargetAssembly("known", Path("ai/targets/known.yml"), [draft_target]),
            },
            skills={"skill": skill, "scalar": scalar_targets_skill},
            load_errors=["error: load failed"],
        )

        errors = collect_source_errors(model, {})
        source_error_outputs, source_error_messages = render_all(model, {})
        outputs = [
            GeneratedFile(Path("same.md"), "", "a", (), Path("same.md")),
            GeneratedFile(Path("same.md"), "", "b", (), Path("same.md")),
            GeneratedFile(Path("../bad.md"), "", "a", (), Path("../bad.md")),
        ]
        output_errors = collect_output_errors(model, {}, outputs)
        class BrokenRenderPlugin(BasePlugin):
            def render(self, model: SourceModel):
                raise KeyError("missing")

        missing_ref_outputs, missing_ref_errors = render_all(
            self._model(
                config={"enabled_platforms": ["known"]},
                platforms={"known": self._platform("known")},
                targets={"known": TargetAssembly("known", Path("ai/targets/known.yml"), [])},
            ),
            {"known": BrokenRenderPlugin(self._platform("known"))},
        )

        self.assertEqual(source_error_outputs, [])
        self.assertTrue(any("load failed" in error for error in source_error_messages))
        self.assertEqual(missing_ref_outputs, [])
        self.assertTrue(
            any(
                "failed to render because source reference is missing" in error
                for error in missing_ref_errors
            )
        )
        self.assertTrue(any("load failed" in error for error in errors))
        self.assertTrue(any("enables unknown platform unknown-enabled" in error for error in errors))
        self.assertTrue(any("fragment is missing frontmatter" in error for error in errors))
        self.assertTrue(any("unsupported status weird" in error for error in errors))
        self.assertTrue(any("targets must be a list" in error for error in errors))
        self.assertTrue(any("targets unknown platform missing" in error for error in errors))
        self.assertTrue(any("target references unknown platform missing-target" in error for error in errors))
        self.assertTrue(any("output is missing id" in error for error in errors))
        self.assertTrue(any("is missing target" in error for error in errors))
        self.assertTrue(any("references unknown scope missing" in error for error in errors))
        self.assertTrue(any("references unknown fragment unknown" in error for error in errors))
        self.assertTrue(any("targets omit known" in error for error in errors))
        self.assertTrue(any("references unknown variant missing" in error for error in errors))
        self.assertTrue(any("renders draft fragment draft without allow_draft" in error for error in errors))
        self.assertTrue(any("active fragment is unreachable" in error for error in errors))
        self.assertTrue(any("skill is missing field" in error for error in errors))
        self.assertTrue(any("unsupported status bad" in error for error in errors))
        self.assertTrue(any("ai/skills/scalar/skill.yml: targets must be a list" in error for error in errors))
        self.assertTrue(any("generated path same.md is produced by both" in error for error in output_errors))
        self.assertTrue(any("escapes the repository" in error for error in output_errors))

    def test_ownership_drift_inventory_and_path_lookup_cover_all_branches(self) -> None:
        with TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            (repo_root / "owned").mkdir()
            (repo_root / "owned" / "extra.md").write_text("manual\n")
            (repo_root / "owned-file.md").write_text("manual\n")
            (repo_root / "stale.md").write_text("old\n")
            (repo_root / "missing-trace.md").write_text("no trace\n")
            (repo_root / "bad").mkdir()
            (repo_root / "bad-generated").mkdir()
            (repo_root / "ok").mkdir()
            (repo_root / "bad" / ".ai-manifest.json").write_text("not-json")
            (repo_root / "bad-generated" / ".ai-manifest.json").write_text('{"generated_by":"other"}')
            (repo_root / "ok" / ".ai-manifest.json").write_text('{"generated_by":"scripts/ai"}')
            model = self._model(
                repo_root=repo_root,
                platforms={
                    "test": self._platform(
                        "test",
                        owned_dirs=[Path("owned"), Path("missing-owned")],
                        owned_files=[Path("owned-file.md")],
                    )
                },
            )
            outputs = [
                GeneratedFile(Path("stale.md"), "new\n", "test", (), Path("stale.md")),
                GeneratedFile(Path("missing.md"), "missing\n", "test", (), Path("missing.md")),
                GeneratedFile(Path("missing-trace.md"), "no trace\n", "test", (), Path("missing-trace.md")),
                GeneratedFile(Path("bad/.ai-manifest.json"), "not-json", "test", (), Path("bad/.ai-manifest.json")),
                GeneratedFile(
                    Path("bad-generated/.ai-manifest.json"),
                    '{"generated_by":"other"}',
                    "test",
                    (),
                    Path("bad-generated/.ai-manifest.json"),
                ),
                GeneratedFile(
                    Path("ok/.ai-manifest.json"),
                    '{"generated_by":"scripts/ai"}',
                    "test",
                    (),
                    Path("manifest-root"),
                ),
            ]

            ownership_errors = collect_ownership_errors(model, outputs)
            stale, extra = collect_drift(model, outputs)
            exact = output_for_path(outputs, Path("stale.md"))
            logical = output_for_path(outputs, Path("manifest-root/child.md"))
            missing = output_for_path(outputs, Path("none.md"))
            inventory = output_inventory(outputs)

        self.assertEqual(stale, ["missing.md", "stale.md"])
        self.assertEqual(extra, ["owned-file.md", "owned/extra.md"])
        self.assertIs(exact, outputs[0])
        self.assertIs(logical, outputs[-1])
        self.assertIsNone(missing)
        self.assertIn(Path("stale.md"), inventory["test"])
        self.assertTrue(any("generated target is missing" in error for error in ownership_errors))
        self.assertTrue(any("was manually edited or is stale" in error for error in ownership_errors))
        self.assertTrue(any("is not valid JSON" in error for error in ownership_errors))
        self.assertTrue(any("lacks generated_by manifest metadata" in error for error in ownership_errors))
        self.assertTrue(any("lacks a trace header" in error for error in ownership_errors))
        self.assertTrue(any("owned by test but no target generates it" in error for error in ownership_errors))
        self.assertTrue(any("inside an owned generated directory" in error for error in ownership_errors))

    def test_plugins_report_platform_specific_errors(self) -> None:
        model = self._model(
            skills={
                "bad": Skill(
                    id="bad",
                    name="Bad_Name",
                    path=Path("ai/skills/bad"),
                    metadata={"targets": ["codex-skills", "cursor", "claude"], "openai": "bad"},
                    instructions_path=Path("ai/skills/bad/missing.md"),
                    reference_paths=[Path("ai/skills/bad/missing-reference.md")],
                    script_paths=[Path("ai/skills/bad/missing-script.sh")],
                )
            },
            targets={},
        )
        agents = AgentsPlugin(self._platform("agents", limits={"max_chars_per_file": 4}))
        copilot = CopilotPlugin(self._platform("copilot"))
        copilot_review = CopilotReviewPlugin(
            self._platform(
                "copilot-review",
                limits={"max_chars_per_file": 4},
                requirements={"required_frontmatter": ["applyTo"]},
            )
        )
        cursor = CursorPlugin(
            self._platform(
                "cursor",
                limits={"always_on_max_chars": 4},
                requirements={"extension": ".mdc", "required_frontmatter": ["description", "alwaysApply"]},
            )
        )
        claude = ClaudePlugin(self._platform("claude"))
        codex = CodexSkillsPlugin(self._platform("codex-skills"))
        agents_output = GeneratedFile(Path("nested/AGENTS.md"), "long content", "agents", (), Path("nested/AGENTS.md"))
        copilot_review_output = GeneratedFile(Path("wrong.md"), "long content", "copilot-review", (), Path("wrong.md"))
        cursor_output = GeneratedFile(Path("wrong.txt"), "long content", "cursor", (), Path("wrong.txt"))

        errors = [
            *agents.validate_output(model, [agents_output]),
            *copilot.validate_output(model, [GeneratedFile(Path("wrong.md"), "", "copilot", (), Path("wrong.md"))]),
            *copilot_review.validate_source(
                self._model(
                    targets={
                        "copilot-review": TargetAssembly(
                            "copilot-review",
                            Path("ai/targets/copilot-review.yml"),
                            [
                                TargetOutput(
                                    id="review",
                                    platform="copilot-review",
                                    path=Path(".github/instructions/review.instructions.md"),
                                    source_path=Path("ai/targets/copilot-review.yml"),
                                    scope="root",
                                    title="Review",
                                    frontmatter={},
                                    limits={},
                                    include=[self._fragment_ref("review", "standard")],
                                    include_imports=[],
                                    allow_draft=False,
                                )
                            ],
                        )
                    }
                )
            ),
            *copilot_review.validate_output(model, [copilot_review_output]),
            *cursor.validate_source(model),
            *cursor.validate_output(model, [cursor_output]),
            *claude.validate_source(model),
            *claude.validate_output(model, []),
            *codex.validate_source(model),
            *codex.validate_output(model, []),
        ]
        with TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            executable_script = repo_root / "script.sh"
            executable_script.write_text("#!/usr/bin/env bash\n")
            executable_script.chmod(0o755)
            (repo_root / "instructions.md").write_text("instructions\n")
            executable_skill = Skill(
                id="exec",
                name="exec",
                path=repo_root,
                metadata={
                    "description": "Executable",
                    "targets": ["codex-skills"],
                    "openai": {
                        "display_name": "Exec",
                        "short_description": "Exec",
                        "default_prompt": "Exec",
                    },
                },
                instructions_path=repo_root / "instructions.md",
                reference_paths=[],
                script_paths=[executable_script],
            )
            ignored_skill = Skill(
                id="ignored",
                name="ignored",
                path=Path("ai/skills/ignored"),
                metadata={"description": "Ignored", "targets": ["other"]},
                instructions_path=Path("ai/skills/ignored/instructions.md"),
                reference_paths=[],
                script_paths=[],
            )
            plugin_error_model = self._model(
                config={"enabled_platforms": ["missing", "bad-plugin"]},
                platforms={"bad-plugin": self._platform("bad-plugin", plugin="missing-plugin")},
            )
            cursor_limit_model = self._model(
                targets={
                    "cursor": TargetAssembly(
                        "cursor",
                        Path("ai/targets/cursor.yml"),
                        [
                            TargetOutput(
                                id="cursor.rule",
                                platform="cursor",
                                path=Path(".cursor/rules/ai/rule.mdc"),
                                source_path=Path("ai/targets/cursor.yml"),
                                scope="root",
                                title="Rule",
                                frontmatter={"description": "Rule", "alwaysApply": True},
                                limits={},
                                include=[],
                                include_imports=[],
                                allow_draft=False,
                            )
                        ],
                    )
                }
            )
            copilot_no_limit_model = self._model(
                targets={
                    "copilot-review": TargetAssembly(
                        "copilot-review",
                        Path("ai/targets/copilot-review.yml"),
                        [
                            TargetOutput(
                                id="review",
                                platform="copilot-review",
                                path=Path(".github/instructions/ai-review/review.instructions.md"),
                                source_path=Path("ai/targets/copilot-review.yml"),
                                scope="root",
                                title="Review",
                                frontmatter={"applyTo": "**", "excludeAgent": "cloud-agent"},
                                limits={},
                                include=[],
                                include_imports=[],
                                allow_draft=False,
                            )
                        ],
                    )
                }
            )
            errors.extend(instantiate_plugins(plugin_error_model)[1])
            errors.extend(
                codex.validate_source(
                    self._model(skills={"exec": executable_skill, "ignored": ignored_skill})
                )
            )
            errors.extend(cursor.validate_source(self._model(skills={"ignored": ignored_skill})))
            errors.extend(cursor.validate_output(self._model(skills={"ignored": ignored_skill}), []))
            errors.extend(codex.validate_source(self._model(skills={"ignored": ignored_skill})))
            errors.extend(codex.validate_output(self._model(skills={"ignored": ignored_skill}), []))
            errors.extend(
                claude.validate_output(
                    model,
                    [GeneratedFile(Path("CLAUDE.md"), "No shared import\n", "claude", (), Path("CLAUDE.md"))],
                )
            )
            errors.extend(
                cursor.validate_output(
                    cursor_limit_model,
                    [
                        GeneratedFile(
                            Path(".cursor/rules/ai/rule.mdc"),
                            "long content",
                            "cursor",
                            (),
                            Path(".cursor/rules/ai/rule.mdc"),
                        )
                    ],
                )
            )
            errors.extend(
                CopilotReviewPlugin(
                    self._platform(
                        "copilot-review",
                        requirements={"required_frontmatter": ["applyTo"]},
                    )
                ).validate_output(
                    copilot_no_limit_model,
                    [
                        GeneratedFile(
                            Path(".github/instructions/ai-review/review.instructions.md"),
                            "content",
                            "copilot-review",
                            (),
                            Path(".github/instructions/ai-review/review.instructions.md"),
                        )
                    ],
                )
            )

        self.assertEqual(AgentsPlugin(self._platform("agents")).render(self._model(targets={})), [])
        self.assertEqual(CopilotPlugin(self._platform("copilot")).render(self._model(targets={})), [])
        self.assertEqual(CopilotReviewPlugin(self._platform("copilot-review")).render(self._model(targets={})), [])
        self.assertEqual(
            CopilotReviewPlugin(self._platform("copilot-review")).validate_source(
                self._model(targets={})
            ),
            [],
        )
        self.assertIn(
            Path("owned"),
            BasePlugin(self._platform("base", owned_dirs=[Path("owned")])).owned_paths(
                self._model()
            ),
        )
        self.assertEqual(BasePlugin(self._platform("base")).render(self._model()), [])
        self.assertEqual(BasePlugin(self._platform("base")).validate_output(self._model(), []), [])
        self.assertIsNone(BasePlugin(self._platform("base")).explain(self._model(), Path("target")))
        self.assertTrue(any("root AGENTS.md" in error for error in errors))
        self.assertTrue(any("nested AGENTS.md" in error for error in errors))
        self.assertTrue(any("would be" in error for error in errors))
        self.assertTrue(any("must be .github/copilot-instructions.md" in error for error in errors))
        self.assertTrue(any("must use compressed variants" in error for error in errors))
        self.assertTrue(any("must end with .instructions.md" in error for error in errors))
        self.assertTrue(any("must be inside .github/instructions/ai-review" in error for error in errors))
        self.assertTrue(any("missing Copilot frontmatter applyTo" in error for error in errors))
        self.assertTrue(any("excludeAgent: cloud-agent" in error for error in errors))
        self.assertTrue(any("must end with .mdc" in error for error in errors))
        self.assertTrue(any("must be inside .cursor/rules/ai" in error for error in errors))
        self.assertTrue(any("Cursor skill names must be lowercase hyphenated" in error for error in errors))
        self.assertTrue(any("Claude-targeted skills need a description" in error for error in errors))
        self.assertTrue(any("CLAUDE.md must import AGENTS.md" in error for error in errors))
        self.assertTrue(any("skill names must be lowercase hyphenated" in error for error in errors))
        self.assertTrue(any("executable skill scripts must be explicitly reviewed" in error for error in errors))
        self.assertTrue(any("missing openai.display_name" in error for error in errors))
        self.assertTrue(any("enables unknown platform missing" in error for error in errors))
        self.assertTrue(any("references unknown plugin missing-plugin" in error for error in errors))
        self.assertTrue(any("must be generated" in error for error in errors))

    def test_cli_commands_cover_success_and_failure_branches(self) -> None:
        self.assertEqual(self._cli_output([])[0], 0)
        absolute_inside = cli._normalize_cli_path(cli.REPO_ROOT / "AGENTS.md")
        absolute_outside = cli._normalize_cli_path(Path("/not/in/repo"))

        with TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            model = self._model(
                repo_root=repo_root,
                config={"enabled_platforms": ["agents", "empty"]},
                platforms={
                    "agents": self._platform("agents"),
                    "empty": self._platform("empty"),
                },
            )
            content = f"<!--\n{TRACE_TEXT}\n-->\nexpected\n"
            outputs = [
                GeneratedFile(
                    Path("AGENTS.md"),
                    content,
                    "agents",
                    ("source",),
                    Path("AGENTS.md"),
                    {"max_chars": 200},
                ),
                GeneratedFile(
                    Path(".agents/skills/ai-instructions/references/authoring.md"),
                    content,
                    "agents",
                    ("source",),
                    Path(".agents/skills/ai-instructions/SKILL.md"),
                    {"max_chars": 200},
                ),
            ]
            for output in outputs:
                actual_path = repo_root / output.path
                actual_path.parent.mkdir(parents=True, exist_ok=True)
                actual_path.write_text(output.content)

            with (
                patch.object(cli, "load_model", return_value=model),
                patch.object(cli, "instantiate_plugins", return_value=({}, [])),
                patch.object(cli, "render_all", return_value=(outputs, [])),
            ):
                validate_code, validate_output = self._cli_output(["validate"])
                check_code, check_output = self._cli_output(["generate", "--check"])
                list_code, list_output = self._cli_output(["list"])
                explain_code, explain_output = self._cli_output(["explain", "AGENTS.md"])
                missing_code, missing_output = self._cli_output(["explain", "not-generated.md"])
                resource_code, resource_output = self._cli_output(
                    ["explain", ".agents/skills/ai-instructions/references/authoring.md"]
                )

        self.assertEqual(validate_code, 0)
        self.assertIn("ok: source files valid", validate_output)
        self.assertEqual(check_code, 0)
        self.assertIn("up to date", check_output)
        self.assertEqual(list_code, 0)
        self.assertIn("agents", list_output)
        self.assertEqual(explain_code, 0)
        self.assertIn("Validation:", explain_output)
        self.assertEqual(missing_code, 1)
        self.assertIn("is not generated", missing_output)
        self.assertEqual(resource_code, 0)
        self.assertIn("File:", resource_output)
        self.assertEqual(absolute_inside, Path("AGENTS.md"))
        self.assertEqual(absolute_outside, Path("/not/in/repo"))

        with TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            model = self._model(
                repo_root=repo_root,
                config={"enabled_platforms": ["empty"]},
                platforms={"empty": self._platform("empty")},
            )
            output = GeneratedFile(
                Path("generated.md"),
                "expected\n",
                "empty",
                ("source",),
                Path("generated.md"),
                {"max_chars": 20},
            )
            with (
                patch.object(cli, "load_model", return_value=model),
                patch.object(cli, "instantiate_plugins", return_value=({}, [])),
                patch.object(cli, "render_all", return_value=([output], [])),
            ):
                explain_missing_code, explain_missing_output = self._cli_output(["explain", "generated.md"])
                generate_code, generate_output = self._cli_output(["generate"])
                (repo_root / "generated.md").write_text("stale\n")
                explain_stale_code, explain_stale_output = self._cli_output(["explain", "generated.md"])

            self.assertEqual(generate_code, 0)
            self.assertIn("wrote generated.md", generate_output)
            self.assertEqual(explain_missing_code, 0)
            self.assertIn("missing", explain_missing_output)
            self.assertEqual(explain_stale_code, 0)
            self.assertIn("stale", explain_stale_output)

        with patch.object(cli, "instantiate_plugins", return_value=({}, ["plugin error"])):
            plugin_code, plugin_output = self._cli_output(["validate"])
        with patch.object(cli, "render_all", return_value=([], ["render error"])):
            validate_error_code, validate_error_output = self._cli_output(["validate"])
            generate_error_code, generate_error_output = self._cli_output(["generate"])
            list_error_code, list_error_output = self._cli_output(["list"])
            explain_error_code, explain_error_output = self._cli_output(["explain", "AGENTS.md"])
        with patch.object(cli, "collect_drift", return_value=(["stale.md"], ["extra.md"])):
            drift_code, drift_output = self._cli_output(["generate", "--check"])
        with patch.object(cli, "output_inventory", return_value={}):
            empty_list_code, empty_list_output = self._cli_output(["list"])
        class UnknownArgs:
            command = "unknown"

        with patch("argparse.ArgumentParser.parse_args", return_value=UnknownArgs()):
            unknown_code, _ = self._cli_output(["unknown"])
        self.assertEqual(plugin_code, 1)
        self.assertIn("plugin error", plugin_output)
        self.assertEqual(validate_error_code, 1)
        self.assertIn("render error", validate_error_output)
        self.assertEqual(generate_error_code, 1)
        self.assertIn("render error", generate_error_output)
        self.assertEqual(list_error_code, 1)
        self.assertIn("render error", list_error_output)
        self.assertEqual(explain_error_code, 1)
        self.assertIn("render error", explain_error_output)
        self.assertEqual(drift_code, 1)
        self.assertIn("stale: stale.md", drift_output)
        self.assertIn("extra: extra.md", drift_output)
        self.assertEqual(empty_list_code, 0)
        self.assertIn("(no generated outputs)", empty_list_output)
        self.assertEqual(unknown_code, 1)

    def _cli_output(self, argv: list[str]) -> tuple[int, str]:
        stream = StringIO()
        with redirect_stdout(stream):
            code = cli.main(argv)
        return code, stream.getvalue()

    def _render_outputs(self):
        model = load_model(REPO_ROOT)
        plugins, plugin_errors = instantiate_plugins(model)
        self.assertEqual(plugin_errors, [])
        outputs, render_errors = render_all(model, plugins)
        self.assertEqual(render_errors, [])
        return outputs

    def _platform(
        self,
        platform_id: str,
        *,
        plugin: str | None = None,
        owned_dirs: list[Path] | None = None,
        owned_files: list[Path] | None = None,
        limits: dict | None = None,
        requirements: dict | None = None,
    ) -> PlatformConfig:
        return PlatformConfig(
            id=platform_id,
            display_name=platform_id,
            plugin=plugin or platform_id,
            path=Path(f"ai/platforms/{platform_id}.yml"),
            owned_exact_dirs=owned_dirs or [],
            owned_exact_files=owned_files or [],
            limits=limits or {},
            requirements=requirements or {},
        )

    def _model(
        self,
        *,
        repo_root: Path = REPO_ROOT,
        config: dict | None = None,
        platforms: dict[str, PlatformConfig] | None = None,
        fragments: dict[str, Fragment] | None = None,
        targets: dict[str, TargetAssembly] | None = None,
        skills: dict[str, Skill] | None = None,
        load_errors: list[str] | None = None,
    ) -> SourceModel:
        return SourceModel(
            repo_root=repo_root,
            config=config or {},
            scopes={"root": Scope("root", "Root", ["**"])},
            fragments=fragments or {},
            platforms=platforms or {},
            targets=targets or {},
            skills=skills or {},
            load_errors=load_errors or [],
        )

    def _fragment_ref(self, fragment: str, variant: str):
        from tools.ai.model import FragmentRef

        return FragmentRef(fragment=fragment, variant=variant)


if __name__ == "__main__":
    unittest.main()
