{% from "mysql/defaults.yaml" import rawmap as defaults with context %}

{% set dockers  = salt['pillar.get']('mysql:dockers', default={}) %}
{% set images = [] %}

{% for name in dockers %}
{% set docker = salt['pillar.get']('mysql:dockers:' ~ name,
                                  default=defaults.docker,
                                  merge=True) %}

{# {% set conf_dir = docker.get('conf_dir', mysql.docker_dir_root ~ '/' ~ name) %#}
{% set image = docker.image if ':' in docker.image else docker.image ~ ':latest' %}
{% do images.append(image) if image not in images %}

mysql-docker-running_{{ name }}:
  dockerng.running:
    - name: {{ name }}
    - image: {{ image }}
    - ports:
      - {{ docker.port }}
{% do docker.environment.append({'MYSQL_ROOT_PASSWORD' : docker.root_password}) %}
    - environment: {{ docker.environment }}
    - binds: '{{ docker.data_dir }}:{{ docker.docker_data_dir }}'
#    - binds: {# { docker.get('binds', conf_dir ~ ':' ~  mysql.conf_dir) } #}
    - require:
      - cmd: mysql-docker-image_{{ image }}

{% if name not in salt['dockerng.list_containers']()  %}
mysql-docker_{{ name }}_-not-found:
  test.fail_without_changes:
    - name: 'docker is not started, mysql cannot connect yet,please retry later'
{% else %}
{% set docker_ip = salt['dockerng.inspect_container'](name).NetworkSettings.IPAddress %}

{% for user_name, user in docker.users.items() %}
mysql-docker-{{ name }}-user-{{ user_name }}:
  mysql_user.present:
    - name: '{{ user_name }}'
    - host: '{{ user.host }}'
    - password: '{{ user.get('password') }}'
    - connection_host: '{{ docker_ip }}'
    - connection_port: {{ docker.port }}
    - connection_user: 'root'
    - connection_pass: '{{ docker.root_password }}'
    - connection_charset: 'utf8'
    - require:
      - dockerng: mysql-docker-running_{{ name }}

  {% for db in user.databases %}
mysql-docker-{{ name }}-user-grant-on_{{ db.database }}:
  mysql_grants.present:
    - grant: {{ db.grants|join(",") }}
    - database: '{{ db.database }}.{{ db.get('table', '*') }}'
    - grant_option: '{{ db.get('grant_option', False) }}'
    - user: '{{ user_name }}'
    - host: '{{ user.host }}'
    - connection_host: '{{ docker_ip }}'
    - connection_port: {{ docker.port }}
    - connection_user: 'root'
    - connection_pass: '{{ docker.root_password }}'
    - connection_charset: 'utf8'
    - require:
      - mysql_user: {{ user_name }}
      - mysql_database: {{ db.database }}
  {% endfor %}

{% endfor %}

{% for db_name, db in docker.databases.items() %}
mysql-db-{{ db_name }}:
  mysql_database.present:
    - name: {{ db_name }}
    - character_set: {{ db.get('character_set', '') }}
    - collate: {{ db.get('collate', '') }}
    - connection_host: '{{ docker_ip }}'
    - connection_port: {{ docker.port }}
    - connection_user: 'root'
    - connection_pass: '{{ docker.root_password }}'
    - require:
      - dockerng: mysql-docker-running_{{ name }}
# TODO: schema
{% endfor %}

{% endif %} # wait for docker start

{% endfor %}

{% for image in images %}
mysql-docker-image_{{ image }}:
  cmd.run:
    - name: docker pull {{ image }}
    - unless: '[ $(docker images -q {{ image }}) ]'
{% endfor %}
