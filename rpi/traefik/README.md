## Instructions
Copy the files

Create Docker network
```
docker network create traefik
```

Generate basic auth password
```
sudo apt-get update
sudo apt-get install apache2-utils

# Generate password hash
htpasswd -nB admin
# Copy the output and replace the users section in dynamic.yml
```

Add Blocky container to Traefik
```
docker network connect traefik blocky-container-name
```

Start Traefik
```
cd ~/traefik
docker-compose up -d

# Check logs
docker-compose logs -f traefik
```
