# [Token Mill](https://github.com/traderjoe-xyz/token-mill)

## Overview

Token Mill is a custom Bonding Curve Automated Market Maker (AMM) that enables users to create tokens with bespoke bonding curves. The bonding curve dictates the token price based on its supply, and users can customize this curve by providing a list of prices for each supply level. Each level consists of `totalSupply / (prices.length - 1)` tokens.

Token Mill offers flexibility by allowing creators to define separate curves for the ask (selling) and bid (buying) sides of the market. This functionality enables the establishment of a bid-ask spread. The resulting spread is then distributed between the protocol and the token creator, with the exact distribution determined by the factory.

The tokens launched on Token Mill will always come from a trusted set of templates. This approach ensures that the tokens are secure and that the bonding curve is correctly implemented. Templates can be added or removed over time, and the factory will always use the latest version of the template.


# Usage

## Documentation

https://docs.tokenmill.xyz/


## Build

```shell
$ forge build
```

## Test

```shell
$ forge test
```

# Contracts

## [Token Mill Factory](./src/TMFactory.sol)

The TokenMill Factory Contract is designed to facilitate the creation and management of markets and tokens with custom bonding curves. This contract allows users to define unique pricing mechanisms for tokens based on their supply, supporting separate curves for bid and ask prices to establish a bid-ask spread.

Key features of the TokenMill Factory Contract include:

- Market and Token Creation: Users can create new markets and tokens with specified parameters, including token type, name, symbol, quote token, total supply, and custom pricing curves.
- Protocol Fee Management: The contract allows setting and updating protocol fee recipients and shares.
- Market and Token Queries: Users can retrieve information about created markets and tokens, such as the creator, protocol share, token type, and associated market.
- Management Functions: The contract supports updating market creators, claiming fees, adding and removing quote tokens, and updating token implementations.

## [Token Mill Market](./src/TMMarket.sol)

The TokenMill Market Contract is designed to facilitate the trading of tokens with custom bonding curves. This contract allows users to buy and sell tokens at prices determined by the bonding curve, which can be customized by the token creator. The bonding curves are stored in the bytecode of the contract making it immutable, making it secure and trustless while way cheaper than storing it in storage.

Key features of the TokenMill Market Contract include:

- Token Trading: Users can buy and sell tokens at prices determined by the bonding curve, with separate curves for bid and ask prices.
- Market Management: The contract supports claiming fees from the spread.
- Token Queries: Users can retrieve information about the token, such as the pricing curves, total supply, and quote token.

## [Router](./src/Router.sol)

The Router Contract is designed to facilitate the trading of tokens within the entire Joe ecosystem. This contract allows users to buy and sell any tokens wether they are created on TokenMill, paired on LB or on Joe V1. The Router will use the route given by the user and calculate the most optimal amounts to buy or sell a token.

Key features of the Router Contract include:

- Token Trading: Users can buy and sell any tokens within the Joe ecosystem.
- Gas Optimization: The contract will use packed routes to save gas on the transaction.

## [Token Mill Templates](./src/templates/)

The TokenMill Templates Contracts should all follow the [BaseERC20](./src/templates/BaseERC20.sol) contract to make sure it is compatible with the TokenMill Factory. Each template will have unique features and functionalities that will be used to create tokens with custom bonding curves while making sure the token is secure and trustless.

Current templates:

- [BasicERC20](./src/templates/BasicERC20.sol): A basic ERC20 token with custom decimals and max supply.

## [Price Points](./src/libraries/PricePoints.sol)

The PricePoints Library is one of the most important libraries in the TokenMill ecosystem. It is used to calculate the price of a token based on the bonding curves and how many tokens to give or receive based on the amount of tokens being bought or sold.

Each price points is distributed evenly between the total supply of the token, starting from 0 to the total supply. The price is calculated using a linear interpolation between each price point.

The curve is defined by the following parameters:

- `totalSupply` - the totalSupply has to follow:

$$
totalSupply \equiv 0 \pmod{n}
$$

- `askPrices` - array of `n+1` prices, all strictly increasing
  $$
  P_{ask} = \bigl [p_{0}^{ask}, p_1^{ask}, ..., p_n^{ask} \bigr ]
  $$
- `bidPrices` - array of `n+1` prices, all strictly increasing and follow:

$$
\forall i \in [0, n], \space p_{ask}(i) \ge p_{bid}(i)
$$

$$
P_{bid} = \bigl [p_{0}^{bid}, p_1^{bid}, ..., p_n^{bid} \bigr ]
$$

In the following equations, we won't differentiate between the ask and bid prices, as the formulas are the same, just using the appropriate price array.

### Supply to Price

$$
P(x) = p_m + \frac{(x - mw)}{w}(p_{m+1}-p_m)
$$

Where:

$$
w = \frac{totalSupply}{n}
$$

$$
m = \biggl  \lfloor \frac{x}{w} \biggr \rfloor
$$

![[Figure 1]: Price Points using the Exponential function, p_min = 10, p_max = 100 and 6 points.](assets/price_graph.png)

[Figure 1]: Price Points using the Exponential function, $P_{min} = 10$, $P_{max} = 100$, $x_{max} = 500 \ 000 \ 000$ and 6 points. [Desmos](https://www.desmos.com/calculator/gu0mpoolmm)

### Base to Quote

$$
y(x) = \Biggl (\space\sum_{i=0}^{m-1} \frac{p_{i+1} + p_i}{2}w\Biggr) + \frac{p_{m+1} - p_m}{2w}{r_x}^2 + r_xp_m
$$

Where:

$$
m = \biggl \lfloor \frac{x}{w} \biggr \rfloor
$$

$$
r_x = x \quad \text{(mod } m \text{)}
$$

### Quote to Base

$$
x(y) = \Biggl( m + \frac{\sqrt{\Delta} - p_m}{p_{m+1}-p_m} \Biggr ) w
$$

Where:

$$
\Delta = {p_m}^2 + \frac{2 * (p_{m+1}-p_m) * r_y}{w}
$$

$$
m = \max_{i \in I}(i)
$$

$$
I = \Biggl \lbrace i \in [0; n] \ \Big| \ \sum_{i=0}^{i-1} \frac{p_{i+1} + p_i}{2}w \le y \Biggr \rbrace
$$

$$
r_y = y - \sum_{i=0}^{m-1} \frac{p_{i+1} + p_i}{2}w
$$


