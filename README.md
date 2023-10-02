# SmolSquid
This project attempts automatising building a docker image with Squid proxy and a container using resulting image.  

The idea is to have a working `proxy docker` with just 1 command that has persistance. Some customisation can be achieved with the available options in `setup.sh`   

## Quick usage
- Copy and paste  
***make sure you can run sudo***
```bash
git clone https://github.com/Gurguii/smolsquid; cd smolsquid; sudo bash setup.sh full
```  
*this will clone the repo and `run the setup script with 'full' option` , which will build the image and create a container that, if everything goes well, will be running and ready to use*  


### Custom listen port and container name  
This will build the image and create out squid proxy docker listening on port 9001.  cache/access/config file will be located inside `/var/mydockers/smolsquid/`
```bash
setup.sh --full --port 9001 --dir /var/mydockers/smolsquid
```  
### Options
![smolsquid_options](https://github.com/Gurguii/SmolSquid/assets/101645735/b4bb47c4-e7a2-4f47-9a65-8b57624bd16b)
## Building image + docker  
![smolsquid_setup](https://github.com/Gurguii/SmolSquid/assets/101645735/410cf7e2-d137-4f3f-8a8d-b8ce92045b09)
## Testing proxy requests
![smolsquid_inaction](https://github.com/Gurguii/SmolSquid/assets/101645735/f41831ff-3182-4fee-a7d1-9cd8d7d113fa)
