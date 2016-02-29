{% from 'emacs/settings.sls' import emacs with context %}

{%- if emacs.from_pkg == True %}
## This is the default behavior, milk-toast if you will.
boring-emacs:
  pkg.installed:
    - name: emacs

{% else %}
# You have chosen wisely but your journey to the great Basillica of St. Stallman has only begin!
{% set build_dir = '/usr/local/src' %}

{% with url = 'https://github.com/emacs-mirror/emacs/archive/%s.tar.gz'|format(emacs.name) %}
emacs|fetch-release:
  archive.extracted:
    - name: {{ build_dir }}
    - source: {{ url }}
    - archive_format: tar
    - source_hash: {{ emacs.hash }}
    - user: root
    - group: root
    - if_missing: {{ build_dir }}/{{ emacs.name }}
      
  file.rename:
    - name: {{ build_dir }}/{{ emacs.name }}
    - source: {{ build_dir }}/emacs-{{ emacs.name }}
    - force: true
{% endwith %}


emacs|source-install:
  pkg.installed:
    - ignore_installed: true
    - reload_modules: true
    - pkgs:
        - git
        - build-essential
        - texinfo

emacs|create-directories:
  # make sure the working dirs are present
  file.directory:
    - names:
        - {{ emacs.prefix }}
    - user: root
    - group: root
    - mode: 755
    - makedirs: true
    - require:
        - pkg: emacs|source-install

emacs|configure-compile:
  # I couldn't figure out how to run `build-dep` using a state so I poked that bit
  # into the build command.  If all goes well, we should have an emacs install by
  # the time the water for your locally-sourced artisinal chai has had time to boil.
  #
  # :NOTE: Someone may want to run the X version and it is disabled here explicitly because
  #   building the X version took even longer. These flags should probably come from a pillar
  cmd.run:
    - name: |
        apt-get build-dep emacs24
        cd {{ build_dir }}/{{ emacs.name }}
        ./autogen.sh
        ./configure --prefix={{ emacs.real_home }} --with-x-toolkit=no --without-x
        make
        make install
    - shell: /bin/bash
    - timeout: 3000
    - unless:
        - test -x {{ emacs.real_home }}/bin/emacs-{{ emacs.version }}

    - cwd: {{ build_dir }}
    - require:
        - file: emacs|fetch-release
        - file: emacs|create-directories
          
  # should end up something like /usr/lib/emacs pointing to this version
  alternatives.install:
    - name: emacs-home-link
    - link: {{ emacs.alt_home }}
    - path: {{ emacs.real_home }}
    - priority: 30
    - require:
        - cmd: emacs|configure-compile
  
# Iterate over the executables and symlink them into /usr/bin
{%- for tag in ['ctags','ebrowse','emacsclient','etags'] %}
emacs|link-{{ tag }}:
  alternatives.install:
    - name: {{ tag }}
    - link: /usr/bin/{{ tag }}
    - path: {{ emacs.bin_dir }}/{{ tag }}
    - priority: 999
    - require:
        - cmd: emacs|configure-compile
{% endfor %}

## Finally, we create a sym-link to our shiny new pinky-bending pal at /usr/bin/emacs
# the version is baked into the executable name and we want the friendlier `emacs` command
emacs|post-install:
  alternatives.install:
    - name: emacs
    - link: /usr/bin/emacs
    - path: {{ emacs.bin_dir }}/emacs-{{ emacs.version }}
    - priority: 999
    - require:
        - cmd: emacs|source-install
{% endif %}
