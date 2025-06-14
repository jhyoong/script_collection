## Instructions

If docker is not installed
```
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker pi
```


Create blocky directory and config
```
mkdir ~/blocky
cd ~/blocky
```

Copy the config file
    - This config files contains custom DNS mapping for traefik to be run on the same machine as well

Run blocky
```
docker run -d \
  --name blocky \
  --restart unless-stopped \
  -p 53:53/udp \
  -p 4000:4000/tcp \
  -v ~/blocky/config.yml:/app/config.yml \
  spx01/blocky
```

Testing and troubleshooting
```
# Check container status
docker ps

# Check logs
docker logs -f blocky

# Test DNS resolution
nslookup google.com 127.0.0.1

# Test ad blocking (should return NXDOMAIN or 0.0.0.0)
nslookup doubleclick.net 127.0.0.1
```
