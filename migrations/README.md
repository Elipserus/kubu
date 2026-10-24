Cada migración es un script `<timestamp unix>.sh` (por ejemplo `date +%s`).
`kubu update` ejecuta, tras el `git pull`, las que no se hayan ejecutado aún y
sean posteriores a la instalación. Deben ser idempotentes.
