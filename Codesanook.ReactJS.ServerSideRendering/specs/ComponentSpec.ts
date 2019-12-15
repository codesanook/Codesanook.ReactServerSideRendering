describe('component', () => {
    const timeoutInSecond = 24 * 60 * 60;
    jest.setTimeout(timeoutInSecond * 1000);

    beforeEach(async () => {
        // To always get a browser object for each test
        await jestPuppeteer.resetBrowser();
    });

    it('should increase number after click button', async () => {
        while (true) {
            await page.goto('http://localhost:9999');

            //let currentValue = await getCounterValue();
            const btnIncrement = await page.waitForSelector('button');
            btnIncrement.click();

            //let newValue = await getCounterValue();
            //expect(newValue).toBe(currentValue + 1);
            //await page.waitFor(3000);
            await page.waitFor(1000);
        }
    });
});

async function getCounterValue(): Promise<number> {
    const valueElement = await page.waitForSelector('h1');
    const property = await valueElement.getProperty('textContent');
    const currentValue = await property.jsonValue() as string;
    return parseInt(currentValue);
}

