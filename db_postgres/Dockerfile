FROM postgres:15

RUN apt-get update && apt-get install -y \
    postgresql-15-cron \
    && rm -rf /var/lib/apt/lists/*

COPY init.sql /docker-entrypoint-initdb.d/

CMD ["postgres", "-c", "shared_preload_libraries=pg_cron", "-c", "cron.database_name=asdf_db"]
