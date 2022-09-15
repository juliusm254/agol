!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

set -e



nginx -c "$PWD/nginx.conf" &

python /app/manage.py collectstatic --no-input &

/usr/local/bin/gunicorn config.wsgi --bind 0.0.0.0:8000 --chdir=/app &

wait -n