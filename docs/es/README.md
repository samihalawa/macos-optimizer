# macOS Optimizer — Guía en Español

<img width="100%" alt="Captura GUI" src="../images/gui-screenshot.png" />

## Resumen

macOS Optimizer ofrece dos interfaces:

1. **CLI** — menú interactivo en terminal (`cli/src/macos-optimizer.sh`)
2. **GUI** — panel web local con NiceGUI (`gui/src/app.py`)

Filosofía: **copias de seguridad primero**, cambios explicados y **sin telemetría**.

## Inicio rápido

### CLI

```bash
chmod +x cli/src/macos-optimizer.sh
./cli/src/macos-optimizer.sh
```

### GUI

```bash
cd gui && python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python src/app.py
```

Abre `http://127.0.0.1:8080`.

## Categorías

- **Rendimiento** — preferencias de respuesta y modo alto rendimiento (opcional)
- **Gráficos** — menos transparencia/motion y animaciones más rápidas
- **Pantalla** — suavizado de fuentes y preferencias de display
- **Almacenamiento** — limpieza prudente de cachés y logs antiguos
- **Red** — ajustes `sysctl` de TCP (pueden reiniciarse al reiniciar)

## Seguridad

1. Haz una copia con Time Machine  
2. Usa la función **Backup** integrada  
3. Aplica una categoría y valida el resultado  
4. Evita ejecutar todo a la vez en el primer uso  

## Datos locales

Todo se guarda en `~/.mac_optimizer/` (backups, logs, perfiles).

## Licencia

MIT — consulta `LICENSE` en la raíz del repositorio.
