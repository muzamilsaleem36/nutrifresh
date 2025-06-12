import os
import time
import requests
import random
import concurrent.futures
from io import BytesIO
from PIL import Image
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

class ImageCrawler:
    def __init__(self, output_dir="fruit_vegetable_dataset"):
        """Initialize the image crawler with output directory."""
        # Use the current working directory for saving images
        self.output_dir = os.path.join(os.getcwd(), output_dir)
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }
        self.fruits = [
            "apple", "banana", "orange", "strawberry", "grape", 
            "mango", "watermelon", "peach", "pineapple", "pear"
        ]
        self.vegetables = [
            "tomato", "potato", "carrot", "broccoli", "cucumber", 
            "spinach", "onion", "bell pepper", "cabbage", "cauliflower"
        ]
        self.conditions = ["fresh", "mid_spoiled", "rotten"]
        
        # Configure Chrome options
        self.chrome_options = Options()
        self.chrome_options.add_argument("--headless")  # Run in headless mode
        self.chrome_options.add_argument("--no-sandbox")
        self.chrome_options.add_argument("--disable-dev-shm-usage")
        
    def setup_directories(self):
        """Create the directory structure for storing images."""
        for item in self.fruits + self.vegetables:
            for condition in self.conditions:
                directory = os.path.join(self.output_dir, item, f"{item}_{condition}")
                os.makedirs(directory, exist_ok=True)
                print(f"Created directory: {directory}")

    def get_search_urls(self, item, condition):
        """Generate search queries for different conditions."""
        search_terms = []
        
        if condition == "fresh":
            search_terms = [
                f"fresh {item}", 
                f"ripe {item}", 
                f"good quality {item}",
                f"fresh {item} fruit" if item in self.fruits else f"fresh {item} vegetable",
                f"perfect {item}",
                f"healthy {item}",
                f"premium {item}",
                f"fresh organic {item}",
                f"just picked {item}",
                f"{item} in perfect condition",
                f"market fresh {item}",
                f"farm fresh {item}",
                f"high quality {item}"
            ]
        elif condition == "mid_spoiled":
            search_terms = [
                f"slightly spoiled {item}", 
                f"overripe {item}", 
                f"aging {item}",
                f"old {item}",
                f"slightly soft {item}",
                f"beginning to spoil {item}",
                f"2 day old {item}",
                f"slightly bruised {item}",
                f"edible but old {item}",
                f"not fresh {item}",
                f"slightly wrinkled {item}",
                f"past prime {item}",
                f"starting to go bad {item}"
            ]
        elif condition == "rotten":
            search_terms = [
                f"rotten {item}", 
                f"spoiled {item}", 
                f"moldy {item}",
                f"decayed {item}",
                f"rotten food {item}",
                f"badly spoiled {item}",
                f"inedible {item}",
                f"decomposing {item}",
                f"spoiled food {item}",
                f"completely rotten {item}",
                f"fungus on {item}",
                f"black spots on {item}",
                f"food waste {item}"
            ]
            
        return search_terms

    def scroll_to_bottom(self, driver):
        """Scroll to the bottom of the page to load more images."""
        last_height = driver.execute_script("return document.body.scrollHeight")
        
        while True:
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(3)  # Wait for page to load
            
            new_height = driver.execute_script("return document.body.scrollHeight")
            if new_height == last_height:
                break
            last_height = new_height

    def download_image(self, img_url, save_path, count):
        """Download an image from the given URL and save it to the specified path."""
        try:
            # Add random delay to prevent overloading servers
            time.sleep(random.uniform(0.5, 2.0))
            
            response = requests.get(img_url, headers=self.headers, timeout=10)
            if response.status_code == 200:
                try:
                    img = Image.open(BytesIO(response.content))
                    
                    # Validate image dimensions and quality
                    if img.width < 100 or img.height < 100:
                        print(f"Image too small, skipping: {img.width}x{img.height}")
                        return False
                    
                    # Convert to RGB if the image is in RGBA mode
                    if img.mode == 'RGBA':
                        img = img.convert('RGB')
                    
                    # Save the image
                    img.save(save_path)
                    print(f"Downloaded: {save_path}")
                    return True
                except Exception as e:
                    print(f"Error processing image: {e}")
            return False
        except Exception as e:
            print(f"Error downloading image {img_url}: {e}")
            return False

    def fetch_images_from_google(self, search_query, item, condition, max_images=350):
        """Fetch images from Google Images for a given search query."""
        
        driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=self.chrome_options)
        
        # Construct the search URL with additional parameters for better results
        search_url = f"https://www.google.com/search?q={search_query}&tbm=isch&tbs=isz:m,itp:photo"
        
        try:
            driver.get(search_url)
            
            # Wait for the images to load
            WebDriverWait(driver, 10).until(
                EC.presence_of_all_elements_located((By.TAG_NAME, "img"))
            )
            
            # Scroll multiple times to load more images
            for _ in range(5):  # Scroll 5 times to load more images
                self.scroll_to_bottom(driver)
                time.sleep(1)
            
            # Find all image elements
            img_elements = driver.find_elements(By.CSS_SELECTOR, "img.rg_i")
            
            # Extract image URLs
            image_urls = []
            for img in img_elements:
                if len(image_urls) >= max_images:
                    break
                
                try:
                    # Click on the image to load the full resolution version
                    img.click()
                    time.sleep(1.5)  # Wait a bit longer for the full image to load
                    
                    # Find the full resolution image
                    full_img = WebDriverWait(driver, 5).until(
                        EC.presence_of_element_located((By.CSS_SELECTOR, "img.r48jcc"))
                    )
                    
                    if full_img.get_attribute("src") and full_img.get_attribute("src").startswith("http"):
                        image_urls.append(full_img.get_attribute("src"))
                except Exception as e:
                    continue
            
            print(f"Found {len(image_urls)} images for search query: {search_query}")
            return image_urls
        
        except Exception as e:
            print(f"Error fetching images for {search_query}: {e}")
            return []
        
        finally:
            driver.quit()

    def download_images_for_item(self, item, condition, target_images=1000):
        """Download images for a specific item and condition."""
        save_dir = os.path.join(self.output_dir, item, f"{item}_{condition}")
        
        # Get search queries for this item and condition
        search_terms = self.get_search_urls(item, condition)
        
        downloaded_count = 0
        search_term_index = 0
        
        while downloaded_count < target_images and search_term_index < len(search_terms):
            search_query = search_terms[search_term_index]
            print(f"Searching for: {search_query}")
            
            # Fetch image URLs
            image_urls = self.fetch_images_from_google(search_query, item, condition)
            
            # Download images
            with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
                futures = []
                for i, img_url in enumerate(image_urls):
                    if downloaded_count >= target_images:
                        break
                    
                    image_name = f"{item}-{condition}{downloaded_count + 1}.png"
                    save_path = os.path.join(save_dir, image_name)
                    
                    futures.append(executor.submit(self.download_image, img_url, save_path, downloaded_count))
                    downloaded_count += 1
                
                # Wait for all futures to complete
                for future in concurrent.futures.as_completed(futures):
                    if not future.result():
                        downloaded_count -= 1  # Adjust count if download failed
            
            search_term_index += 1
            
        print(f"Downloaded {downloaded_count} images for {item} in {condition} condition")
        return downloaded_count

    def run(self):
        """Run the crawler to download all required images."""
        print(f"Creating dataset in: {self.output_dir}")
        self.setup_directories()
        
        total_downloaded = 0
        
        # Download fruits
        for fruit in self.fruits:
            for condition in self.conditions:
                print(f"\n===== Starting download for {fruit} - {condition} =====")
                count = self.download_images_for_item(fruit, condition)
                total_downloaded += count
                print(f"===== Completed {fruit} - {condition}: {count} images =====\n")
                
        # Download vegetables
        for vegetable in self.vegetables:
            for condition in self.conditions:
                print(f"\n===== Starting download for {vegetable} - {condition} =====")
                count = self.download_images_for_item(vegetable, condition)
                total_downloaded += count
                print(f"===== Completed {vegetable} - {condition}: {count} images =====\n")
                
        print(f"\nTotal images downloaded: {total_downloaded}")
        print(f"Dataset created at: {self.output_dir}")
        print("Directory structure and file naming follows the requested format:")
        print("  - fruit/fruit_condition/fruit-condition#.png")
        print("  - vegetable/vegetable_condition/vegetable-condition#.png")
        
        # Show sample paths as examples
        print("\nExample paths:")
        print(f"  - {os.path.join(self.output_dir, 'apple', 'apple_fresh', 'apple-fresh1.png')}")
        print(f"  - {os.path.join(self.output_dir, 'tomato', 'tomato_mid_spoiled', 'tomato-mid_spoiled1.png')}")
        print(f"  - {os.path.join(self.output_dir, 'banana', 'banana_rotten', 'banana-rotten1.png')}")


# Run the crawler
if __name__ == "__main__":
    print("Starting Image Crawler for Fruits and Vegetables Dataset")
    print("This will download images for 10 fruits and 10 vegetables in 3 conditions each.")
    print("Images will be saved in the current working directory.")
    print("==================================================================")
    
    # Create the crawler and run it
    crawler = ImageCrawler(output_dir="fruit_vegetable_dataset")
    crawler.run()
