# my-sysadmin-scripts

Учебный проект курса «Системное администрирование» (МИФИ, SkillFactory): скрипт мониторинга ресурсов, упакованный в Docker и развёрнутый за Nginx с HTTPS на виртуалке Ubuntu 22.04.

## Скрипт

`script.sh` раз в 10 секунд снимает `free -h`, `df -h` и `uptime` и дописывает их в `monitor.log` блоком с временной меткой.

```bash
./script.sh
MAX_ITERATIONS=3 ./script.sh
LOG_FILE=/tmp/monitor.log ./script.sh
```

- `MAX_ITERATIONS` - сколько замеров сделать, по умолчанию 0 (без ограничения).
- `LOG_FILE` - куда писать, по умолчанию `monitor.log` в текущем каталоге.
- Остановка: Ctrl+C или `kill`, в лог допишется строка об остановке.

Пример вывода - в `sample_output.txt`.

## Контейнер

`Dockerfile` собирает образ на `ubuntu:22.04` с `procps` (в базовом образе нет `free` и `uptime`) и `python3`. В контейнере скрипт пишет лог в `/var/www`, а `python3 -m http.server 8080` отдаёт его по HTTP.

```bash
docker build -t my-script .
docker compose up
```

`docker compose up` делает 3 замера и пишет их в `out/monitor.log` через том.

## Стенд

```text
клиент ──HTTPS:443──> Nginx ──HTTP──> 127.0.0.1:8080 ──> контейнер my-app (systemd)
                                                            │
                                               /mnt/raid/my-app (RAID 1, /dev/md0)
```

| Файл | Что делает |
|---|---|
| `deploy/storage.sh` | Создаёт RAID 1 (`/dev/md0` из двух loop-устройств по 512 МБ) и LVM (`vg_data/lv_logs`), монтирует их в `/mnt/raid` и `/mnt/logs`. Повторный запуск подключает уже созданные диски |
| `deploy/storage-lab.service` | Запускает `storage.sh` при загрузке, до Docker |
| `deploy/my-app.service` | Запускает контейнер `my-app` через systemd |
| `deploy/nginx-my-app.conf` | Nginx: редирект с HTTP на HTTPS и reverse proxy на `127.0.0.1:8080` |
| `deploy/check.sh` | Проверки стенда: `part1` (Docker, RAID, LVM), `part2` (Nginx, HTTPS, systemd, логи), без аргумента - всё |

## Развёртывание на чистой Ubuntu 22.04

```bash
sudo apt install -y docker.io docker-compose-v2 docker-buildx mdadm lvm2 nginx
sudo usermod -aG docker "$USER" && newgrp docker
sudo install -m 755 deploy/storage.sh /usr/local/sbin/storage.sh
sudo install -m 644 deploy/storage-lab.service deploy/my-app.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now storage-lab
docker build -t my-script .
sudo mkdir -p /mnt/raid/my-app
docker create --init --name my-app -p 127.0.0.1:8080:8080 \
  -v /mnt/raid/my-app:/var/www -v /etc/localtime:/etc/localtime:ro my-script
sudo systemctl enable --now my-app
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/my-app.key -out /etc/ssl/certs/my-app.crt -subj "/CN=my-app.local"
sudo install -m 644 deploy/nginx-my-app.conf /etc/nginx/sites-available/my-app
sudo ln -sf /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/my-app
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
deploy/check.sh
```

После перезагрузки машины всё поднимается само: `storage-lab` заново подключает loop-устройства и собирает RAID, затем стартуют Docker, `my-app` и Nginx.
