# visualizador-orquestrador

Un navegador de ejecuciones del orquestador de emanación, de solo lectura.

```
bash visualizador-orquestrador                 # lista todas las ejecuciones
bash visualizador-orquestrador --session <id>  # abre una directamente
```

## Qué es

Lee `.inspire/emanate-runs/` — lo que el propio orquestador ya escribe en cada
ejecución (`state.json` por run, reescrito en cada `run.save()`) — y lo sirve
por HTTP a un front en React sin paso de build (React + [htm](https://github.com/developit/htm)
vía `esm.sh`, un único `index.html`). El front hace polling cada 2 s mientras
la ejecución sigue en curso.

No escribe nada en `.inspire/`, no toca git, no habla con el checkpoint de
LangGraph — solo lee JSON ya existente. Zero dependencias nuevas: el servidor
es `http.server` de la librería estándar de Python.

## Piezas

- `cli.py` — el punto de entrada (`argparse`, detecta la raíz del repo con
  `git rev-parse`, abre el navegador).
- `server.py` — dos endpoints (`/api/runs`, `/api/runs/<id>/state`) más los
  estáticos de `web/`. `python3 visualizer/server.py` corre su propio
  autocheck (`demo()`).
- `web/index.html` — la interfaz: lista de ejecuciones, y por ejecución las
  olas, las piezas de cada ola con su fase y su línea de tiempo, los
  reintentos gastados por rol, y los hallazgos (drops, stalls, rechazos).

## Lo que no hace (todavía)

- No expone el texto de cada spawn de agente (`run_dir/spawns/`) — son
  ficheros que pueden ser grandes y conviene paginar antes de servirlos.
- No lee `checkpoint.sqlite` — el historial de transiciones de LangGraph. El
  timeline por pieza que `state.json` ya trae cubre el caso de uso normal
  (¿en qué fase está, cuánto lleva, cuántos reintentos) sin necesitar hablar
  con esa base de datos.
