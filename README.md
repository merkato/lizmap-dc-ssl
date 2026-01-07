## Requirements

- Docker Engine also knonw as Docker CE
- Docker Compose plugin

Środowisko Docker wraz z konfiguracją podsieci instalujemy przy pomocy
```bash
./prepare_server.sh
```
Nastąpi instalacja pakietów dockera z repo, a następnie instalacja, rekonfiguracja deamona, aby korzystał z podsieci 192.168.199.x i 192.168.200.x, a potem jego restart

### Linux
Upewnij się że  uruchamiasz całość poza kontem administratora, a użytkownika dopisałeś już do grupy docker. W tej chwili prepare_server.sh już o to dba.


W pierwszej kolejności uruchom konfigurację, która utworzy struktury katalogów, oraz ustawi zmienne systemowe:
```bash
./configure.sh configure
```

Następnie uruchom kontenery:
```bash
docker compose pull
docker compose up -d
```

Wejdź w NPM
http://adres-ip:81 

Utwórz nowy Proxy host, adres wewnętrzny web, port 8080, Block Common Exploits, Websockets Support
W zakładce SSL wskaż źródło certyfikatu. Force SSL, HTTP/2 Support.

W prawym górnym rogu ustawienia zaawansowane:
```
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header Host $host;
```

Lizmap powinna być dostępna pod https://twoj-ip


## Pierwsze uruchomienie

Default login `admin`, password `admin`. Zapyta cię o zmianę po pierwszym logowaniu, zrób to.

## Add your own project

Po kolei:
* utwórz katalog w `lizmap/instances` 
* zajrzyj do http://localhost:8090/admin.php/admin/maps/
* W panelu admina Lizmap, dodaj katalog który utworzyłeś
* Dodaj jeden lub więcej projektów QGIS (.qgs + .cfg) do tego katalogu.

## Reset the configuration

In command line

```bash
./configure.sh  clean 
```

This will remove all previous configuration. You will have to reenter the configuration in Lizmap
as for the first run.

## References

For more information, refer to the [docker-compose documentation](https://docs.docker.com/compose/)

See also:

- https://github.com/3liz/lizmap-web-client
- https://github.com/3liz/py-qgis-server

Docker on Windows:

- https://docs.docker.com/desktop/windows/
- https://docs.microsoft.com/fr-fr/windows/dev-environment/docker/overview
