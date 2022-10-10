deploy-omtf:
	forge script script/Deploy.s.sol\:DeployScript \
	  --fork-url http://localhost:8545 \
		--sig "deployMembershipTokenFactory()" \
		--broadcast --verify -vvvv

deploy-ogtf:
	forge script script/Deploy.s.sol\:DeployScript \
	  --fork-url http://localhost:8545 \
		--sig "deployGovernanceTokenFactory()" \
		--broadcast --verify -vvvv

deploy-omt:
	forge script script/Deploy.s.sol\:DeployScript \
	  --fork-url http://localhost:8545 \
		--sig "deployMembershipToken(address,string,string,string)" \
		--broadcast --verify -vvvv --\
		 $(admin) $(name) $(symbol) $(base-uri)

deploy-ogt:
	forge script script/Deploy.s.sol\:DeployScript \
	  --fork-url http://localhost:8545 \
		--sig "deployGovernanceToken(address,string,string,uint256)" \
		--broadcast --verify -vvvv --\
		 $(admin) $(name) $(symbol) $(supply-cap)

clone-omt:
	forge script script/Clone.s.sol:Clone \
	  --fork-url http://localhost:8545 \
		--sig "cloneMembershipToken(address,address,string,string,string)" 
		--broadcast -vvvv --\
		$(factory-proxy-address) $(admin) $(name) $(symbol) $(base-uri)

clone-ogt:
	forge script script/Clone.s.sol:Clone \
	  --fork-url http://localhost:8545 \
		--sig "deployGovernanceToken(address,string,string,uint256)" \
		--broadcast -vvvv --\
		$(factory-proxy-address) $(admin) $(name) $(symbol) $(supply-cap)