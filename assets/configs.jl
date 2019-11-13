# This file contains the game configs!
# In debug builds, this file is reloaded in real-time -- every
# `config_reload_time_s` seconds, so you test changes on the fly just by
# modifying these constants.
# In release builds, this file is only included once, during compilation, so
# these values are all defined once as globals.

defaultFontName = "assets/fonts/FiraCode/ttf/FiraCode-Regular.ttf"
defaultFontSize = 26
SDLGamesLib.set_default_font(defaultFontName, defaultFontSize)

minWinWidth = Int32(20)  # basically 0.
minWinHeight = Int32(425)  # Prevent getting any smaller than this.

# Menu constants
kPauseSceneTitleFontSize = 40
kPauseSceneSubtitleFontSize = 30

kMenuButtonFontSize = 20
kKeyButtonFontSize = 16
kMenuButtonColor = SDL2.Color(80, 80, 200, 255)
kKeySettingButtonColor = SDL2.Color(185, 55, 48, 255)

kControlsHeaderFontSize = 15

kProgrammedWithJuliaText = ["Programmed with ", " ", " using Julialang ", ""]
kCopyrightNotices = ["Copyright (c) 2018 @nhdalyMadeThis, LLC.",
                     "Theme music copyright http://www.freesfx.co.uk"]

# Game Rendering
kBackgroundColor = SDL2.Color(210,210,210,255)
kBuildOpsBgColor = SDL2.Color(210,210,210,0x80)
kFighterColor = SDL2.Color(0,0,0xff,0xff)
kCollectorColor = SDL2.Color(0,0,0,0x55) # transparent

kP1Color = SDL2.Color(58, 95, 224, 255)
kP2Color = SDL2.Color(203, 60, 51, 255)

kFoodColor = SDL2.Color(0,210,0,50)
kFoodSize = 50

kUIFontSize = 13
kBuildOpsRenderHeight = kUIFontSize + 25

# UI
kCamZoomRate = 10 # pixel/scroll-click
kCamPanRate = 500 # pixel/second

kCamMinSize = 10 # can't zoom closer than 10 world pixels.

kMouseEdgeDetectionWidth = 50

# Unit Attributes

kMaxHealth_Collector = 10
kMaxHealth_Fighter = 20

kAttackDamage_Collector = 1
kAttackDamage_Fighter = 5

kBuildTime_Collector = 5
kBuildTime_Fighter = 10
kBuildCost_Collector = 3
kBuildCost_Fighter = 5

kMoneyPersecPercollector = 1/1.0 # 1 every n secs

kFighterSpeed = 100 # feet/sec

# Game constants
kRandPurchaseCollectorPosRange = 50
kRandPurchaseFighterPosRange = 300

kFoodDistributionFreq = 100 # pixels / food
kFoodSheetDriftAccel = 50 # pixels / food
kFoodSheetDriftMaxSpeed_sqrd = 10^2 # pixels / food
kFoodAmount = 10


paddleSpeed = 1000
paddleTimeToMaxSpeed = 0.15
paddleTimeToDecelerate = 0.05
paddleAccel = paddleSpeed/paddleTimeToMaxSpeed
paddleDeccel = paddleSpeed/paddleTimeToDecelerate
collectorSpeed = 350

unitRenderWidth=10
collectorRenderWidth=20
healthBarRenderOffset = 3
healthBarRenderWidth = 18; healthBarRenderHeight = 2
healthBarColor = SDL2.Color(0,210,0,255)
healthBarOutlineColor = SDL2.Color(0x99,0x99,0x99,0xff)

winningScore = 11


# meta config
config_reload_time_s = 1  # seconds

# Code Testing
#set_health!(p1.units.collectors[2], 5)
#println(p1.units.collectors[2].health)

knight_dims = (77,59)
knight_pos = (130,8)
knight_run_offset = 2
knight_jump_offset = 3
knight_anim_delays = [1, 1, 1, 2, 1, 1, 1,] ./ 10
knight_display_scale = 0.3
