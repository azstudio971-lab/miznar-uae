import {test,expect} from '@playwright/test';
test.beforeEach(async({page})=>{await page.route('**/functions/v1/catalog',route=>route.fulfill({json:{themes:[],library:[],music:[],updates:[],settings:{}}}));await page.route('**/functions/v1/location-info**',route=>route.fulfill({json:{weather:null,prayer:null}}));});
test('four tabs, persisted greeting and car entertainment',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto('/');await expect(page.locator('.phone-tabs button')).toHaveCount(4);
 await page.locator('[data-tab=settings]').click();await page.locator('#username').fill('راشد');await page.locator('#username').blur();await page.locator('.phone-tabs [data-tab=home]').click();await expect(page.locator('.welcome')).toContainText('راشد');await expect(page.locator('.car-hero')).toContainText('راشد');
 await page.locator('[data-car=entertainment]').click();await expect(page.locator('.entertainment-screen')).toContainText('المفضلة');
 await page.reload();await expect(page.locator('.welcome')).toContainText('راشد');expect(errors).toEqual([]);
});
test('admin exposes login and policies render',async({page})=>{await page.goto('/admin');await expect(page.locator('#login')).toBeVisible();await expect(page.locator('#login button')).toBeEnabled();for(const route of ['privacy','terms','support','delete']){await page.goto('/'+route);await expect(page.locator('h1')).not.toBeEmpty();}});
