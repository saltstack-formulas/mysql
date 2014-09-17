{% from "mysql/defaults.yaml" import rawmap with context %}
{% set datamap = salt['grains.filter_by'](rawmap, merge=salt['pillar.get']('mysql:server:lookup')) %}

{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', 'somepass') %}

{% if grains['os'] in ['Ubuntu', 'Debian'] %}
mysql-debconf:
  debconf.set:
    - name: mysql-server
    - data:
        'mysql-server/root_password': {'type': 'password', 'value': '{{ mysql_root_password }}'}
        'mysql-server/root_password_again': {'type': 'password', 'value': '{{ mysql_root_password }}'}
        'mysql-server/start_on_boot': {'type': 'boolean', 'value': 'true'}
{% elif grains['os'] in ['CentOS'] %}
mysql-root-password:
  cmd:
    - run
    - name: mysqladmin --user root password '{{ mysql_root_password|replace("'", "'\"'\"'") }}'
    - unless: mysql --user root --password='{{ mysql_root_password|replace("'", "'\"'\"'") }}' --execute="SELECT 1;"
    - require:
      - service: mysqld

{% for host in ['localhost', grains['fqdn']] %}
mysql-delete-anonymous-user-{{ host }}:
  mysql_user:
    - absent
    - host: {{ host }}
    - name: ''
    - connection_pass: {{ mysql_root_password }}
    - require:
      - service: mysqld
      - pkg: mysql-python
      {%- if mysql_root_password %}
      - cmd: mysql-root-password
      {%- endif %}
{% endfor %}
{% endif %}

mysqld:
  pkg:
    - installed
    - name: {{ datamap.server }}
{% if grains['os'] in ['Ubuntu', 'Debian'] %}
    - require:
      - debconf: mysql-debconf
{% endif %}
  service:
    - running
    - name: {{ datamap.service }}
    - enable: True
    - watch:
      - pkg: mysqld

my.cnf:
  file.managed:
    - name: {{ datamap.config.file }}
    - source: salt://mysql/files/my.cnf
    - template: jinja
    #- watch_in:
    #  - service: mysqld
    {% if grains['os'] in ['Ubuntu', 'Debian', 'Gentoo', 'CentOS'] -%}
    - user: root
    - group: root
    - mode: 644
{% endif %}
