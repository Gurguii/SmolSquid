# SmolSquid
This project attempts automatising building a docker image with Squid proxy and a container using resulting image.  

The idea is to have a working `proxy docker` with just 1 command that has persistance. Some customisation can be achieved with the available options in `setup.sh`   

**Image size: 18-24Mb (tested in Arch and Manjaro)**

## Quick usage
- Copy and paste  
***make sure you can run sudo***
```bash
git clone https://github.com/Gurguii/smolsquid; cd smolsquid; sudo bash setup.sh --full
```  
*this will clone the repo and `run the setup script with 'full' option` , which will build the image and create a container that, if everything goes well, will be running and ready to use*  


### Custom listen port and container name  
This will build the image and create out squid proxy docker listening on port 9001.  cache/access/config file will be located inside `/var/mydockers/smolsquid/`
```bash
setup.sh --full --port 9001 --dir /var/mydockers/smolsquid
```  
### Options
![smolsquid_options](https://github.com/Gurguii/SmolSquid/assets/101645735/10f41176-56f4-4ce4-8222-e390dda82882)


## Building image + docker  
![smolsquid_setup_complete](https://github.com/Gurguii/SmolSquid/assets/101645735/8fd00322-2883-4194-ab9a-92d83fe03425)
   
## Testing proxy requests
![smolsquid_inaction](https://github.com/Gurguii/SmolSquid/assets/101645735/477bfd11-1bac-4aaf-a9f9-a997b2794543)
