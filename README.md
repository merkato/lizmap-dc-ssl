## Requirements

- Docker Engine also knonw as Docker CE
- Docker Compose plugin

### Linux

In a shell, configure the environment:
```bash
./configure.sh configure
```
Jeśli używamy SFTP dodaj linie z env.sftp do .env do env.default i configure.sh


Run the stack:
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


## Running the first time

The previous commands create a docker-compose environment and run the stack

The Lizmap service will start two toys projects that you will have to configure in the Lizmap
interface.

See the [Lizmap documentation](https://docs.lizmap.com) for how to configure Lizmap at first run.

Default login is `admin`, password `admin`. It will be asked to change it at first login.

## Add your own project

You need to :
* create a directory in `lizmap/instances` - uwaga - popraw SFTP
* visit http://localhost:8090/admin.php/admin/maps/
* in the Lizmap admin panel, add the directory you created
* add one or more QGIS projects with the Lizmap CFG file in the directory

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
