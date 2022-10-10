# The Origami family of smart contracts

## contract synopsis

| Contract                        | Purpose                                                        |
| :------------------------------ | :------------------------------------------------------------- |
| `OrigamiMembershipToken`        | A membership NFT issued to DAO members                         |
| `OrigamiMembershipTokenFactory` | A factory contract for cheaply deploying new membership tokens |
| `OrigamiGovernanceToken`        | An ERC20 token appropriate for use in governance               |
| `OrigamiGovernanceTokenFactory` | A factory contract for cheaply deploying new governance tokens |

## development

We power our solidity development with `foundry`. The [book](https://book.getfoundry.sh) is a great jumping off point. [Awesome Foundry](https://github.com/crisgarner/awesome-foundry) does a great job of showcasing common patterns implemented using `foundry`. Run `forge` from the project directory after installing the prerequisites to get an idea of the capabilities.

### Pre Requisites

1. Ensure you've created a `.env` file (`cp {example,}.env`), populated its values and exported them to your shell (`direnv` is a convenient way of managing this).
2. Install `cargo`: `curl https://sh.rustup.rs -sSf | sh`
3. Install `foundry` ([instructions and details](https://book.getfoundry.sh/getting-started/installation)): 
  * `curl -L https://foundry.paradigm.xyz | bash`
  * `foundryup`
4. Install `argc`: `cargo install argc`

### Testing

Tests are implemented in Solidity and use `foundry` to power them. The documentation for writing tests using `foundry` is [thorough](https://book.getfoundry.sh/forge/tests) and there is an active community in their telegram.

The simplest test invocation is:

```sh
$ forge test
```

Running tests with 3 levels of verbosity provides extensive feedback on failures and gas usage estimates. Combining this with watch mode makes for a tight feedback loop:

```sh
$ forge test -vvv -w
```

### Coverage

Generate a coverage report:

```sh
$ forge coverage
```

## deploying

Forthcoming.