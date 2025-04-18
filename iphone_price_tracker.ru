import os
import requests
from bs4 import BeautifulSoup
import telegram
import time

TELEGRAM_TOKEN = os.getenv("TELEGRAM_TOKEN")
CHAT_ID = int(os.getenv("CHAT_ID"))
CATALOG_URL = "https://killprice24.ru/catalog/apple-iphone?page=all"
CHECK_INTERVAL = 60 * 60
HEADERS = { "User-Agent": "Mozilla/5.0" }

bot = telegram.Bot(token=TELEGRAM_TOKEN)
price_cache = {}

def get_all_product_links():
    response = requests.get(CATALOG_URL, headers=HEADERS)
    soup = BeautifulSoup(response.text, "html.parser")
    links = []
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if href.startswith("/products/") and href not in links:
            links.append("https://killprice24.ru" + href)
    return links

def get_price_and_name(url):
    response = requests.get(url, headers=HEADERS)
    soup = BeautifulSoup(response.text, "html.parser")
    title = soup.select_one("h1")
    price_block = soup.select_one(".product-page-price .price")
    if not title or not price_block:
        raise Exception(f"Не удалось найти цену или название на {url}")
    name = title.get_text(strip=True)
    price = price_block.get_text(strip=True).replace(" ", "").replace("₽", "")
    return name, int(price)

def notify(name, old_price, new_price, url):
    message = f"Цена изменилась:\n{name}\n{old_price:,}₽ → {new_price:,}₽\n{url}".replace(",", " ")
    bot.send_message(chat_id=CHAT_ID, text=message)

def run():
    global price_cache
    product_links = get_all_product_links()
    for url in product_links:
        try:
            name, current_price = get_price_and_name(url)
            previous_price = price_cache.get(url)
            if previous_price is None:
                price_cache[url] = current_price
            elif current_price != previous_price:
                notify(name, previous_price, current_price, url)
                price_cache[url] = current_price
            time.sleep(1)
        except Exception as e:
            print(f"Ошибка: {e}")

while True:
    try:
        run()
    except Exception as e:
        bot.send_message(chat_id=CHAT_ID, text=f"Ошибка в боте: {e}")
    time.sleep(CHECK_INTERVAL)
