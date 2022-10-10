deploy-omtf:
	forge script script/Deploy.s.sol\:DeployScript \
	  --fork-url http://localhost:8545 \
		--sig "membershipTokenFactory()" \
		--broadcast --verify -vvvv

deploy-omt:
	forge script script/Deploy.s.sol\:DeployScript \
	  --fork-url http://localhost:8545 \
		--sig "membershipToken(address,string,string,string)" \
		--broadcast --verify -vvvv --\
		 $(admin) $(name) $(symbol) $(base-uri)

clone-omt:
	forge script script/Clone.s.sol:Clone \
	  --fork-url http://localhost:8545 \
		--sig "cloneMembershipToken(address,address,string,string,string)" 
		--broadcast -vvvv --\
		$(factory-proxy-address) $(admin) $(name) $(symbol) $(base-uri)
