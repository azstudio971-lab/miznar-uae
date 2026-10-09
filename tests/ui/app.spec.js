import {test,expect} from '@playwright/test';
test('Arabic preview changes period, layout and personal greeting without errors',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/preview');
 await expect(page.locator('html')).toHaveAttribute('dir','rtl');
 await page.locator('#preview-name').fill('راشد');await expect(page.locator('#scene .clock')).toContainText('راشد');
 await page.locator('[data-period="night"]').click();await expect(page.locator('#scene img')).toHaveAttribute('src','/media/ultrawide/night.png');
 await page.locator('#shape').click();await expect(page.locator('#scene')).toHaveClass(/compact/);
 await expect(page.locator('#scene img')).toHaveJSProperty('naturalWidth',1402);
 await page.locator('#lang').click();await expect(page.locator('html')).toHaveAttribute('dir','ltr');
 await expect(page.getByRole('heading',{name:'Your space, on every journey'})).toBeVisible();expect(errors).toEqual([]);
});
test('Unconfigured admin cannot pretend to save data',async({page})=>{await page.goto('/admin');await expect(page.locator('#login button[type="submit"],#login button:not([type])').first()).toBeDisabled();await expect(page.getByText('الاتصال السحابي لم يُهيّأ بعد.',{exact:false})).toBeVisible();});
test('All public policies render in both languages',async({page})=>{for(const route of ['privacy','terms','support','delete']){await page.goto('/'+route);await expect(page.locator('h1')).not.toBeEmpty();await page.locator('#lang').click();await expect(page.locator('h1')).not.toBeEmpty();}});
