{% from "telegraf/map.jinja" import telegraf_grains with context %}
{%- set agent = telegraf_grains.telegraf.get('agent', {}) %}
{%- if agent.get('enabled', False) %}

telegraf_packages_agent:
  pkg.installed:
    - names: {{ agent.pkgs }}

telegraf_config_agent:
  file.managed:
    - name: {{ agent.dir.config }}/telegraf.conf
    - source: salt://telegraf/files/telegraf.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - pkg: telegraf_packages_agent
    - context:
      agent: {{ agent }}

config_d_dir_agent:
  file.directory:
    - name: {{agent.dir.config_d}}
    - makedirs: True
    - mode: 755
    - require:
      - pkg: telegraf_packages_agent

config_d_dir_agent_clean:
  file.directory:
    - name: {{agent.dir.config_d}}
    - clean: True
    - watch_in:
      - service: telegraf_service_agent

{%- for name,values in agent.input.items() %}

{%- if values is not mapping or values.get('enabled', True) %}
input_{{ name }}_agent:
  file.managed:
    - name: {{ agent.dir.config_d }}/input-{{ name }}.conf
    - source:
{%- if values.template is defined %}
      - salt://{{ values.template }}
{%- endif %}
      - salt://telegraf/files/input/{{ name }}.conf
      - salt://telegraf/files/input/generic.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - pkg: telegraf_packages_agent
      - file: config_d_dir_agent
    - require_in:
      - file: config_d_dir_agent_clean
    - watch_in:
      - service: telegraf_service_agent
    - defaults:
        name: {{ name }}
{%- if values is mapping %}
        values: {{ values }}
{%- else %}
        values: {}
{%- endif %}

{%- if name in ('ceph', 'docker', 'haproxy') %}
telegraf_user_in_group_{{ name }}:
  user.present:
    - name: telegraf
    - optional_groups:
      - {{ name }}
    - require:
      - pkg: telegraf_packages_agent
{%- endif %}

{%- endif %}

{%- endfor %}

{%- for name,values in agent.output.items() %}

output_{{ name }}_agent:
  file.managed:
    - name: {{ agent.dir.config_d }}/output-{{ name }}.conf
    - source: salt://telegraf/files/output/{{ name }}.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - pkg: telegraf_packages_agent
      - file: config_d_dir_agent
    - require_in:
      - file: config_d_dir_agent_clean
    - watch_in:
      - service: telegraf_service_agent
    - defaults:
        name: {{ name }}
{%- if values is mapping %}
        values: {{ values }}
{%- else %}
        values: {}
{%- endif %}

{%- endfor %}

telegraf_service_agent:
  service.running:
    - name: telegraf
    - enable: True
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}
    - watch:
      - file: telegraf_config_agent

{%- endif %}
