$log = kubectl logs deploy/frontend -n dev --tail=100
$richieste = $log | Select-String "request complete"
$tempi = $richieste | ForEach-Object { ($_ | ConvertFrom-Json).'http.resp.took_ms' }
$tempi | Measure-Object -Average