{% from 'emacs/settings.sls' import emacs with context %}

{%- if emacs.from_pkg == True %}
install-emacs:
  pkg.installed:
    - pkgs:
        - emacs
{% else %}


## Pull down a github release of the desired version
emacs-fetch-release:
  archive.extracted:
    - name: {{ emacs.build_dir }}
    - source: {{ emacs.base_url|format(emacs.version) }}
    - archive_format: tar
    - source_hash: {{ emacs.hash }}
    - user: root
    - group: root
    - if_missing: {{ emacs.build_dir }}/{{ emacs.name }}
      
  file.rename:
    - name: {{ emacs.build_dir }}/{{ emacs.name }}
    - source: {{ emacs.build_dir }}/emacs-{{ emacs.name }}
    - force: true

emacs-dependencies:
  pkg.installed:
    - ignore_installed: true
    - reload_modules: true
    - pkgs:
        - git
        - build-essential
        - texinfo

emacs-create-directories:
  file.directory:
    - names:
        - {{ emacs.prefix }}
    - user: root
    - group: root
    - mode: 755
    - makedirs: true
    - require:
        - pkg: emacs-source-install

emacs-configure-compile:
  # I couldn't figure out how to run `build-dep` using a state so I poked that bit
  # into the build command.  If all goes well, we should have an emacs install by
  # the time the water for your locally-sourced artisinal chai has had time to boil.
  #
  # :NOTE: Someone may want to run the X version and it is disabled here explicitly because
  #   building the X version took even longer. These flags should probably come from a pillar
  #
  # :NOTE: This should really be broken up into separate steps since configre and make can each take
  #   several minutes to complete on the smaller systems. 
  cmd.run:
    - name: |
        apt-get build-dep emacs24
        cd {{ emacs.build_dir }}/{{ emacs.name }}
        ./autogen.sh
        ./configure --prefix={{ emacs.real_home }} --with-x-toolkit=no --without-x
        make
        make install
    - shell: /bin/bash
    - timeout: 3000
    - unless:
        - test -x {{ emacs.real_home }}/bin/emacs-{{ emacs.version }}

    - cwd: {{ emacs.build_dir }}
    - require:
        - file: emacs-fetch-release
        - file: emacs-create-directories
          
  # should end up something like /usr/lib/emacs pointing to this version
  alternatives.install:
    - name: emacs-home-link
    - link: {{ emacs.alt_home }}
    - path: {{ emacs.real_home }}
    - priority: 30
    - require:
        - cmd: emacs-configure-compile
  
# the above build has created binaries in {{ emacs.bin_dir }} and in order to
# preserve the ability to switch between versions, sym-links are created in /usr/bin
{%- for tag in ['ctags','ebrowse','emacsclient','etags'] %}
emacs-link-{{ tag }}:
  alternatives.install:
    - name: {{ tag }}
    - link: /usr/bin/{{ tag }}
    - path: {{ emacs.bin_dir }}/{{ tag }}
    - priority: 999
    - require:
        - cmd: emacs-configure-compile
{% endfor %}

# The emacs binary is built with the version baked into the name (emacs-25.0.91)
# create a sym-link with a high priority at `/usr/bin/emacs`
emacs-post-install:
  alternatives.install:
    - name: emacs
    - link: /usr/bin/emacs
    - path: {{ emacs.bin_dir }}/emacs-{{ emacs.version }}
    - priority: 999
    - require:
        - cmd: emacs-source-install
{% endif %}
