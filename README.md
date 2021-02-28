## TASK LIST
- [x] Write a infrastructure as code specification that deploys a "Hello world" lambda functionor with SAM or serverless.
- [x] Modify your code to provision a SNS topic with terraform.
- [ ] Extend the above lambda function to fetch the latest blocks and send a notification to an SNS topic for each new block.
The task is partially done. The functions fetches the latest block from the api https://blockchain.info/latestblock and writes it to console. 

## TODO
- [ ] Add trigger for function.
- [ ] Save state about the current block.
- [ ] Add logic for comparsion the current block and the latest block.
- [ ] Add send notification to SNS function.
- [ ] Add subscription for the created topic/

## CHECK

```
cd terraform
terraform init
terraform plan
tarraform apply
```

## DESTROY RESOURCES

```
terraform destroy
```
