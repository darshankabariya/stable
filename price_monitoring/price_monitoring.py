import requests
import pandas as pd
import time

# Uniswap V3 subgraph URL
subgraph_url = "https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v3"

# Dictionary of tokens with their Ethereum addresses
tokens = {
    1: ("USDT", "0xdAC17F958D2ee523a2206206994597C13D831ec7"),
    2: ("USDC", "0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"),
    3: ("DAI", "0x6B175474E89094C44Da98b954EedeAC495271d0F"),
    4: ("WETH", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"),  # Wrapped ETH
    # Add more tokens as needed
}

def fetch_token_price(token0_address, token1_address):
    query = f"""
    {{
      pools(where: {{token0: "{token0_address}", token1: "{token1_address}"}}) {{
        id
        token0 {{
          symbol
        }}
        token1 {{
          symbol
        }}
        token0Price
        token1Price
      }}
    }}
    """
    response = requests.post(subgraph_url, json={'query': query})
    if response.status_code == 200:
        data = response.json()
        return data['data']['pools']
    else:
        raise Exception(f"Query failed with status code {response.status_code}")

def monitor_token_price(token0_address, token1_address):
    while True:
        try:
            prices = fetch_token_price(token0_address, token1_address)
            df = pd.DataFrame(prices)
            print(df[['token0', 'token1', 'token0Price', 'token1Price']])
        except Exception as e:
            print(f"Error fetching token price: {e}")
        time.sleep(60)  # Fetch prices every minute

def main():
    # Display tokens
    print("Available tokens:")
    for id, (name, _) in tokens.items():
        print(f"{id}: {name}")

    # Select tokens
    try:
        token0_id = int(input("Enter the ID of the first token: "))
        token1_id = int(input("Enter the ID of the second token: "))

        token0_name, token0_address = tokens[token0_id]
        token1_name, token1_address = tokens[token1_id]

        print(f"Monitoring price of {token0_name} against {token1_name}...")
        monitor_token_price(token0_address, token1_address)
    except KeyError:
        print("Invalid token ID selected.")
    except ValueError:
        print("Please enter a valid number.")

if __name__ == "__main__":
    main()