Config = {}

Config.Debug = true
Config.TickTime = 1 -- Time in minutes that food & water tick down by 1 & health is checked

Config.Stages = {
    {
        label = 'Germination',
        prop = 'bkr_prop_weed_01_small_01c',
        growTime = 30, -- In minutes
    },
    {
        label = 'Seedling',
        prop = 'bkr_prop_weed_01_small_01b',
        growTime = 30,
    },
    {
        label = 'Vegetative',
        prop = 'bkr_prop_weed_01_small_01a',
        growTime = 30,
    },
    {
        label = 'Budding',
        prop = 'bkr_prop_weed_med_01b',
        growTime = 30,
    },
    {
        label = 'Pre-flowering',
        prop = 'bkr_prop_weed_lrg_01a',
        growTime = 30,
    },
    {
        label = 'Flowering',
        prop = 'bkr_prop_weed_lrg_01b',
        growTime = 30,
    },
    {
        label = 'Ready for harvest',
        prop = 'bkr_prop_weed_lrg_01b',
        growTime = 60, -- Amount of time before plant dies
    },
}

Config.Strains = {
    ogkush = {
        label = 'OGKush 2g',
        item = 'weed_ogkush',
        stages = Config.Stages,
    },
    amnesia = {
        label = 'Amnesia 2g',
        item = 'weed_amnesia',
        stages = Config.Stages,
    },
    skunk = {
        label = 'Skunk 2g',
        item = 'weed_skunk',
        stages = Config.Stages,
    },
    ak47 = {
        label = 'AK47 2g',
        item = 'weed_ak47',
        stages = Config.Stages,
    },
    purplehaze = {
        label = 'Purple Haze 2g',
        item = 'weed_purplehaze',
        stages = Config.Stages,
    },
    whitewidow = {
        label = 'White Widow 2g',
        item = 'weed_whitewidow',
        stages = Config.Stages,
    },
}