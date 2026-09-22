import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / 'chezmoi/dot_local/bin/executable_agent-resume'
loader = importlib.machinery.SourceFileLoader('recovery', str(SOURCE))
spec = importlib.util.spec_from_loader(loader.name, loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        m.BASE = Path(self.tmp.name)
        m.SPEC = m.BASE / 'specs'
        self.agent = {'agent': 'claude', 'id': '00000000-0000-0000-0000-000000000001',
                      'home': str(Path.home() / '.claude'), 'cwd': '/tmp'}

    def test_save_exact_id_without_changing_layout(self):
        layout = m.BASE / 'layout.txt'
        geometry = 'window\twork\t2\t:topic\t1\t:*\tgeometry\t:'
        layout.write_text('pane\twork\t2\t1\t:*\t1\ttitle\t:/tmp\t1\tzsh\t:claude\n' + geometry + '\n')
        with patch.object(m, 'processes', return_value={10: (1, 'zsh'), 11: (10, 'claude')}), \
             patch.object(m, 'discover', return_value={11: self.agent}), \
             patch.object(m, 'run', return_value='work\t2\t1\t10\n'):
            m.save(layout)
        self.assertIn('agent-resume', layout.read_text())
        self.assertIn(geometry, layout.read_text())
        self.assertEqual(json.loads(next(m.SPEC.glob('*.json')).read_text()), self.agent)

    def test_ambiguous_agents_are_not_guessed(self):
        layout = m.BASE / 'layout.txt'
        original = 'pane\twork\t2\t1\t:*\t1\ttitle\t:/tmp\t1\tzsh\t:zsh\n'
        layout.write_text(original)
        with patch.object(m, 'processes', return_value={10: (1, 'zsh'), 11: (10, 'claude'), 12: (10, 'claude')}), \
             patch.object(m, 'discover', return_value={11: self.agent, 12: self.agent}), \
             patch.object(m, 'run', return_value='work\t2\t1\t10\n'):
            m.save(layout)
        self.assertEqual(layout.read_text(), original)

    def launch(self, agent):
        key = m.store(agent)
        with patch.object(m, 'processes', return_value={}), \
             patch.object(m, 'discover', return_value={}), \
             patch.object(m.os, 'chdir'), \
             patch.object(m.shutil, 'which', side_effect=lambda name: '/example/bin/' + name), \
             patch.object(m.os, 'execvpe') as execute, \
             patch.dict(m.os.environ, {'NO_COLOR': '1', 'CLAUDE_CONFIG_DIR': 'wrong'}):
            m.resume(key)
        return execute.call_args.args

    def test_default_claude_profile_and_color(self):
        _, args, env = self.launch(self.agent)
        self.assertNotIn('NO_COLOR', env)
        self.assertNotIn('CLAUDE_CONFIG_DIR', env)
        self.assertEqual(args, ['/example/bin/claude', '--resume', self.agent['id']])

    def test_personal_claude_profile(self):
        agent = self.agent | {'home': '/tmp/alternate-agent-home'}
        _, _, env = self.launch(agent)
        self.assertEqual(env['CLAUDE_CONFIG_DIR'], agent['home'])

    def test_codex_exact_home_directory_and_color(self):
        agent = self.agent | {'agent': 'codex', 'home': '/tmp/alternate-codex-home'}
        _, args, env = self.launch(agent)
        self.assertEqual(args, ['/example/bin/codex', 'resume', agent['id'], '-C', '/tmp'])
        self.assertEqual(env['CODEX_HOME'], agent['home'])
        self.assertNotIn('NO_COLOR', env)

    def test_duplicate_is_not_started(self):
        key = m.store(self.agent)
        with patch.object(m, 'processes', return_value={}), \
             patch.object(m, 'discover', return_value={11: self.agent}), \
             patch.object(m.os, 'execvpe') as execute:
            m.resume(key)
        execute.assert_not_called()

    def test_key_rejects_path_traversal(self):
        with self.assertRaises(ValueError):
            m.resume('../../private-file')


if __name__ == '__main__':
    unittest.main()
