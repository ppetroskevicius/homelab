import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

source = Path(__file__).resolve().parents[1] / 'chezmoi/dot_local/bin/executable_open-terminal-link'
loader = importlib.machinery.SourceFileLoader('terminal_links', str(source))
spec = importlib.util.spec_from_loader(loader.name, loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)


class TerminalLinksTests(unittest.TestCase):
    def test_urls_and_punctuation(self):
        self.assertEqual(m.destination('(https://github.com/example/repo/pull/42).'),
                         'https://github.com/example/repo/pull/42')
        self.assertEqual(m.destination('https://example.org/a_(b)'), 'https://example.org/a_(b)')

    def test_embedded_link_overrides_label(self):
        self.assertEqual(m.destination('read more', hyperlink='https://example.org/help'),
                         'https://example.org/help')

    def test_embedded_url_preserves_exact_punctuation(self):
        url = 'https://example.org/question?'
        self.assertEqual(m.destination('help', hyperlink=url), url)

    def test_qualified_reference(self):
        self.assertEqual(m.destination('example-org/my-repo#42,'),
                         'https://github.com/example-org/my-repo/issues/42')

    def test_clicked_repository_is_used(self):
        completed = subprocess.CompletedProcess([], 0, 'git@github.com:example/target.git\n', '')
        with patch.object(m.subprocess, 'run', return_value=completed) as run:
            self.assertEqual(m.destination('#42', Path('/clicked/pane')),
                             'https://github.com/example/target/issues/42')
        self.assertEqual(run.call_args.args[0][2], '/clicked/pane')

    def test_https_origin(self):
        completed = subprocess.CompletedProcess([], 0, 'https://github.com/example/target.git\n', '')
        with patch.object(m.subprocess, 'run', return_value=completed):
            self.assertEqual(m.destination('PR#42', '/tmp'), 'https://github.com/example/target/issues/42')

    def test_ambiguous_and_non_web_input_rejected(self):
        for value in ['42', '#42', 'file:///etc/passwd', 'javascript:alert(1)', 'https://example.org/\narg']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                m.destination(value)

    def test_non_github_remote_rejected(self):
        completed = subprocess.CompletedProcess([], 0, 'https://example.org/example/target.git\n', '')
        with patch.object(m.subprocess, 'run', return_value=completed), self.assertRaises(ValueError):
            m.destination('#42', '/tmp')

    def test_browser_receives_one_literal_url_argument(self):
        url = 'https://example.org/$(touch-no-file)?q=a&b=2'
        with patch.object(m.sys, 'platform', 'darwin'):
            self.assertEqual(m.browser_command(url), ['/usr/bin/open', '-a', 'Google Chrome', url])


if __name__ == '__main__':
    unittest.main()
