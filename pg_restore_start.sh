#!/bin/bash

# Cargando las variables de entorno del archivo .env
set -o allexport
source .env
set +o allexport

# Origen de la base de datos
ORIGEN_HOST="$ORIGEN_HOST"
ORIGEN_PORT="$ORIGEN_PORT"
ORIGEN_USER="$ORIGEN_USER"
ORIGEN_PASS="$ORIGEN_PASS"

# Destino de la base de datos
DESTINO_HOST="$DESTINO_HOST"
DESTINO_PORT="$DESTINO_PORT"
DESTINO_USER="$DESTINO_USER"
DESTINO_PASS="$DESTINO_PASS"


# Listado de bases de datos a copiar del origen al destino
DATABASES=(
    # dev1_gestion_autorizacion
    # dev1_tutorias
    # dev1_gestion_talento_humano
)

# Directorio temporal para almacenar los backups
BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"

# Exportar credenciales para pg_dump y psql
export PGPASSWORD="$ORIGEN_PASS"

# Iteramos sobre las bases de datos a copiar
for db in "${DATABASES[@]}"
do
    echo "PROCESANDO LA BASE DE DATOS: $db"

    # Backup de la base de datos en el origen
    BACKUP_FILE="$BACKUP_DIR/${db}.sql"
    echo "Haciendo backup de $db desde $ORIGEN_HOST..."
    pg_dump -h "$ORIGEN_HOST" -p "$ORIGEN_PORT" -U "$ORIGEN_USER" -d "$db" -F c -f "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo "Error al hacer backup de la base de datos $db."
        continue
    fi

    # Eliminar la base de datos en el destino si ya existe

    echo "Eliminando la base de datos $db en el destino $DESTINO_HOST..."
    PGPASSWORD="$DESTINO_PASS" psql -h "$DESTINO_HOST" -p "$DESTINO_PORT" -U "$DESTINO_USER" -c "DROP DATABASE IF EXISTS $db;"
    if [ $? -ne 0 ]; then
        echo "-----> Error al eliminar la base de datos $db en el destino."
        continue
    fi


    # Crear la base de datos en el destino
    echo "Creando la base de datos $db en el destino $DESTINO_HOST..."
    PGPASSWORD="$DESTINO_PASS" psql -h "$DESTINO_HOST" -p "$DESTINO_PORT" -U "$DESTINO_USER" -c "CREATE DATABASE $db;"
    if [ $? -ne 0 ]; then
        echo "Error al crear la base de datos $db en el destino."
        continue
    fi

    # Restaurar el backup en el destino
    echo "Restaurando $db en el destino $DESTINO_HOST..."
    PGPASSWORD="$DESTINO_PASS" pg_restore -h "$DESTINO_HOST" -p "$DESTINO_PORT" -U "$DESTINO_USER" -d "$db" "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo -e "Error al restaurar la base de datos $db.\n\n"
        continue
    fi

    echo -e "Base de datos $db copiada exitosamente.\n\n"
done

# Limpieza de backups
echo "Limpieza de archivos temporales de backup..."
rm -rf "$BACKUP_DIR"

echo "Script completado."