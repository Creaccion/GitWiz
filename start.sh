
set -euo pipefail

ROOT="$(pwd)"
echo "[GitWiz] Working directory: $ROOT"

# Carpeta legacy
mkdir -p lua/gitwiz/old

# Mover directorios si existen (sin fallar si no)
for d in actions utils telescope config; do
  if [ -d "lua/gitwiz/$d" ]; then
    mv "lua/gitwiz/$d" "lua/gitwiz/old/$d"
    echo "Moved lua/gitwiz/$d -> lua/gitwiz/old/$d"
  fi
done

# Copia de archivos sueltos relevantes (si quieres conservarlos)
for f in log.lua init.lua; do
  if [ -f "lua/gitwiz/$f" ]; then
    cp "lua/gitwiz/$f" "lua/gitwiz/old/${f%.lua}_orig.lua"
    echo "Copied lua/gitwiz/$f -> lua/gitwiz/old/${f%.lua}_orig.lua"
  fi
done

# Crear nueva estructura
mkdir -p lua/gitwiz/core
mkdir -p lua/gitwiz/domain
mkdir -p lua/gitwiz/actions
mkdir -p lua/gitwiz/ui/telescope

echo "[GitWiz] New structure ready."

