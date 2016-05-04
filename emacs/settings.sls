{%- load_yaml as emacs_defaults %}
prefix: /usr/local/lib
version: 25.0.91
archive_url: "https://github.com/emacs-mirror/emacs/archive/emacs-%(version)s.tar.gz"
alt_home: /usr/local/lib/emacs
from_pkg: True
build_dir: /usr/local/src
{%- endload %}

{% set emacs = salt['pillar.get']('emacs', emacs_defaults, merge=True) %}
{% do emacs.update({
  'real_home': '%s-%s'|format(emacs.alt_home, emacs.version),
  'name': 'emacs-%s'|format(emacs.version),
  'bin_dir': '%s/bin'|format(emacs.alt_home)}) %}

