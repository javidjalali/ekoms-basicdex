const USDT_ART = artifacts.require('USDT');
const UNI_ART = artifacts.require('Uni');
const LINK_ART = artifacts.require('LinkToken');
const Dex_ART = artifacts.require('Dex');

contract('Dex', () => {
    
    //Contracts
    let dex;
    let USDT;
    let UNI;
    let LINK;

    //String literals
    let USDT_TICKER;
    let UNI_TICKER;
    let LINK_TICKER;
    [USDT_TICKER, UNI_TICKER, LINK_TICKER] = ['USDT', 'UNI', 'LINK'];

    //Will run before each test
    beforeEach(async() => {
        [(USDT, UNI, LINK)] = await Promise.all([
            USDT_ART.new(),
            UNI_ART.new(),
            LINK_ART.new()
        ]);
        dex = await Dex_ART.new();
    })
})