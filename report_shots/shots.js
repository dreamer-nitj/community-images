const puppeteer = require('puppeteer');
const process = require('process');
const util = require('util');
const fs = require('fs/promises');
const yaml = require('js-yaml')

async function takeShots(imageSavePath, imageUrl) {
  const browser = await puppeteer.launch({headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']});
  const page = await browser.newPage();

  await page.setViewport({
    width: 5120,
    height: 3840,
    deviceScaleFactor: 8,
  });

  await page.setViewport({width: 3600, height: 2160});

  await page.goto(imageUrl, { waitUntil: 'networkidle0' }); // wait until page load
  await page.emulateMediaFeatures([{
    name: 'prefers-color-scheme', value: 'light' }]);

  // Select light theme
  await page.waitForSelector("#App > div:nth-child(1) > div.page.docker-image-page > div > header > div > div > div > div.header__right-view > div");
  await page.click("#App > div:nth-child(1) > div.page.docker-image-page > div > header > div > div > div > div.header__right-view > div");

  await page.waitForSelector('#carousel__container');
  const metrics = await page.$('#carousel__container');
  await metrics.screenshot({
    path: util.format('%s/metrics.png', imageSavePath)
    });

    // #card-statistics-histogram

  await page.waitForSelector('#card-statistics-histogram');
  const cve_details = await page.$('#card-statistics-histogram');
  await cve_details.screenshot({
    path: util.format('%s/cve_reduction.png', imageSavePath)
    });

  await page.close();
  await browser.close();
  console.log("screen shots taken");
}

async function main() {
  const imgListPath = process.argv[2]

  const imgList = await fs.readFile(imgListPath, { encoding: 'utf8' });
  const imgListArray = imgList.split("\n");
  console.log(imgListArray);

  imgListArray.forEach(async(imagePath) => {
    console.log(imagePath);
    const imageSavePath = util.format('../community_images/%s/assets', imagePath);
    console.log(imageSavePath);

    let imageYmlPath = util.format('../community_images/%s/image.yml', imagePath);

    let imageYmlContents = await fs.readFile(imageYmlPath, { encoding: 'utf8' });
    let imageYml = yaml.load(imageYmlContents);

    await takeShots(imageSavePath, imageYml.report_url);
  });
}

main();
