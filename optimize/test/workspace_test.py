import json
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lib'))
# Exercise our adapter without installing or invoking SkillOpt's training engine.
for name, member in [('skillopt.datasets.base', 'SplitDataLoader'), ('skillopt.envs.base', 'EnvAdapter')]:
    module = types.ModuleType(name)
    setattr(module, member, object)
    sys.modules[name] = module

import driver
import inspire_env as env


class WorkspaceTest(unittest.TestCase):
    def test_diff_tracks_additions_deletions_and_large_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'edited.ts').write_text('old defect\nunchanged\n')
            (root / 'deleted.ts').write_text('removed\n')
            before = env._snapshot(root)
            (root / 'edited.ts').write_text('old defect\nunchanged\nnew defect\n')
            (root / 'deleted.ts').unlink()
            (root / 'new.ts').write_text('new\n')
            (root / 'large.ts').write_text('x' * 200001)
            (root / 'empty.ts').touch()
            changes = env._changes(root, before)
            self.assertEqual(changes['edited.ts']['added'], [{'line': 3, 'text': 'new defect'}])
            self.assertIn(' old defect', changes['edited.ts']['patch'])
            self.assertEqual(changes['deleted.ts']['after'], None)
            self.assertIn('-removed', changes['deleted.ts']['patch'])
            self.assertIsNone(changes['new.ts']['before'])
            self.assertIn('No newline at end of file', changes['large.ts']['patch'])
            self.assertEqual(len(changes['large.ts']['after']), 200001)
            self.assertEqual(changes['empty.ts']['after'], '')
            self.assertEqual(env._changes(root, env._snapshot(root)), {})
            (root / 'binary').write_bytes(b'\0binary')
            with self.assertRaisesRegex(ValueError, 'binary'):
                env._changes(root, before)

    def test_rollouts_start_from_the_same_seed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            template, fixture = root / 'template', root / 'fixture'
            skill = '.claude/skills/example/SKILL.md'
            (template / skill).parent.mkdir(parents=True)
            (template / skill).write_text('original')
            (template / 'code.ts').write_text('base')
            fixture.mkdir()
            (fixture / 'code.ts').write_text('task seed')
            adapter = env.InspireAdapter.__new__(env.InspireAdapter)
            adapter.workspace_template = template
            adapter.skill_name = 'example'
            adapter.frontmatter = ''
            adapter.exec_timeout = 1
            item = {'id': 'one', 'prompt': 'implement', 'fixture': str(fixture), 'checks': [], 'task_type': 'example'}
            def agent(work, prompt, timeout):
                self.assertEqual((work / 'code.ts').read_text(), 'task seed')
                self.assertEqual((work / skill).read_text(), 'candidate')
                (work / 'code.ts').write_text('agent output')
                return 'done'
            def checks(context, paths):
                ctx = json.loads(context.read_text())
                self.assertEqual(set(ctx['changes']), {'code.ts'})
                self.assertIn('-task seed', ctx['diff'])
                self.assertIn('+agent output', ctx['diff'])
                return {'score': 1, 'passed': True, 'results': []}
            with patch.object(env, '_run_agent', agent), patch.object(env, '_run_checks', checks):
                adapter._rollout_one(item, 'candidate', root / 'out')
                adapter._rollout_one(item, 'candidate', root / 'out')
            self.assertEqual((template / 'code.ts').read_text(), 'base')
            self.assertEqual((fixture / 'code.ts').read_text(), 'task seed')

    def test_fixture_overlays_current_runtime_and_dry_run_validates_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            seed = root / 'seed'
            (seed / 'source').mkdir(parents=True)
            (seed / 'source/code.ts').write_text('seed')
            (seed / '.claude').mkdir()
            (seed / '.claude/stale').write_text('old runtime')
            (seed / 'node_modules').mkdir()
            (seed / 'node_modules/ignored').touch()
            driver.prepare_workspace('example', {'fixture': str(seed)}, root / 'workspace')
            self.assertEqual((root / 'workspace/source/code.ts').read_text(), 'seed')
            self.assertTrue((root / 'workspace/.inspire.lock').is_file())
            self.assertFalse((root / 'workspace/.claude/stale').exists())
            self.assertFalse((root / 'workspace/node_modules').exists())
            with self.assertRaisesRegex(SystemExit, 'fixture not found'):
                driver.resolve_items('example', {'fixture': str(root / 'missing'), 'tasks': 'skills/inspire-adr/tasks/*.md'})

    def test_skills_can_use_different_bases(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            def materialize(command, cwd=None, **kwargs):
                return None
            with patch.object(driver.subprocess, 'run', materialize):
                for name in ['react', 'nestjs']:
                    seed = root / name
                    seed.mkdir()
                    (seed / 'code.ts').write_text(name)
                    driver.prepare_workspace(name, {'fixture': str(seed)}, root / f'{name}-work')
                self.assertEqual((root / 'react-work/code.ts').read_text(), 'react')
                self.assertEqual((root / 'nestjs-work/code.ts').read_text(), 'nestjs')


if __name__ == '__main__':
    unittest.main()
