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
		 $(owner) $(name) $(symbol) $(base-uri)