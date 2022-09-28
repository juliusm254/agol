ARG PYTHON_VERSION=3.9-slim-bullseye



# define an alias for the specfic python version used in this file.
FROM python:${PYTHON_VERSION} as python

# Python build stage
FROM python as python-build-stage

ARG BUILD_ENVIRONMENT=production


# Install apt packages
RUN apt-get update && apt-get install --no-install-recommends -y \
  # dependencies for building Python packages
  build-essential \
  # psycopg2 dependencies
  libpq-dev

# Requirements are installed here to ensure they will be cached.
COPY ./requirements .

# Create Python Dependency and Sub-Dependency Wheels.
RUN pip wheel --wheel-dir /usr/src/app/wheels  \
  -r ${BUILD_ENVIRONMENT}.txt


# Python 'run' stage
FROM python as python-run-stage

ARG BUILD_ENVIRONMENT=production
ARG APP_HOME=/app

ENV PYTHONUNBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1
ENV BUILD_ENV ${BUILD_ENVIRONMENT}

WORKDIR ${APP_HOME}



RUN addgroup --system django \
    && adduser --system --ingroup django django



# Install required system dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
  # psycopg2 dependencies
  libpq-dev \
  # Translations dependencies
  gettext \
  nginx \ 
	bash \
  # cleaning up unused files
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/*

# All absolute dir copies ignore workdir instruction. All relative dir copies are wrt to the workdir instruction
# copy python dependency wheels from python-build-stage
COPY --from=python-build-stage /usr/src/app/wheels  /wheels/

# use wheels to install python dependencies
RUN pip install --no-cache-dir --no-index --find-links=/wheels/ /wheels/* \
  && rm -rf /wheels/


COPY --chown=django:django ./entrypoint /entrypoint
RUN sed -i 's/\r$//g' /entrypoint
RUN chmod +x /entrypoint

COPY --chown=django:django ./nginx.conf /etc/nginx/conf.d/configfile.template

ADD nginx.conf /etc/nginx/nginx.conf
RUN sed -i 's/\r$//g' /etc/nginx/nginx.conf
RUN chmod +x /etc/nginx/nginx.conf
RUN chown django: /var/log/nginx/error.log


COPY --chown=django:django ./start /start
RUN sed -i 's/\r$//g' /start
RUN chmod +x /start

#my shit for start script

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static /tini
# COPY --chown=django:django ./usr/bin/tini /etc/nginx/nginx.conf
RUN chown django: /tini
RUN chmod +x /tini

# copy application code to WORKDIR
COPY --chown=django:django . ${APP_HOME}

# make django owner of the WORKDIR directory as well.
RUN chown django:django ${APP_HOME}


USER django

# ENTRYPOINT ["/entrypoint"]
ENV PORT 8080

ENTRYPOINT ["/tini", "--"]

# CMD [ "/entrypoint", "/start" ]

# FROM traefik:v2.2.11
# RUN mkdir -p /etc/traefik/acme \
#   && touch /etc/traefik/acme/acme.json \
#   && chmod 600 /etc/traefik/acme/acme.json
# COPY ./compose/production/traefik/traefik.yml /etc/traefik
CMD [ "start", "./start","envsubst '\$PORT' < /etc/nginx/conf.d/configfile.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
