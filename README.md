# Headscale
Deploy self hosted Headscale to AWS

- Request an AWS Open Environment from demo.redhat.com
- Clone this repo: `git clone https://github.com/redhat-dod/headscale.git & cd headscale`
- Install the aws cli, authenticate into your account. 
- Install jq
- Configure variables in config.sh

Run the script:
```bash
./0-run.sh
```

- [ ] finish config.yaml settings for headscale pod 
- [ ] template out config.yaml 
- [ ] update user-data.sh script to finalize automated deploy of headscale