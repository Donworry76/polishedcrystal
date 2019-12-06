HasOpponentEndturnSwitched:
	call CallOpponentTurn
HasUserEndturnSwitched:
; 4gen+ handles endturn switches (after faints) rather late. To avoid the need
; to rewrite switching extensively, this function is used to bypass endturn
; events that happens before a 4gen faint switch-in happens, since in 2gen,
; the switch happens earlier.
	ld a, [hBattleTurn]
	and a
	ld a, [wPlayerEndturnSwitched]
	jr z, .got_endturnswitch
	ld a, [wEnemyEndturnSwitched]
.got_endturnswitch
	xor 1 ; return z if we have endturn switched
	ret

CheckFaint:
	ld a, [hSerialConnectionStatus]
	cp USING_EXTERNAL_CLOCK
	jr z, .enemy_first
	call .check_player
	call nc, .check_enemy
	ret

.enemy_first
	call .check_enemy
	call nc, .check_player
	ret

.check_player
	call HasPlayerFainted
	jr nz, .ok
	call HandlePlayerMonFaint
	ld a, [wBattleEnded]
	and a
	jr nz, .over
	ret

.check_enemy
	call HasEnemyFainted
	jr nz, .ok
	call HandleEnemyMonFaint
	ld a, [wBattleEnded]
	and a
	jr nz, .over
	ret

.ok
	and a
	ret
.over
	scf
	ret

HandleBetweenTurnEffects:
; Things handled at endturn. Things commented out are currently not in Polished.
	call CheckFaint
	ret c
	call HandleWeather
	call CheckFaint
	ret c
	; Self-curing status from high Affection
	call HandleFutureSight
	call CheckFaint
	ret c
	; Wish
	call HandleEndturnBlockA
	call CheckFaint
	ret c
	; aqua ring
	; ingrain
	call HandleLeechSeed
	call CheckFaint
	ret c
	call HandlePoison
	call CheckFaint
	ret c
	call HandleBurn
	call CheckFaint
	ret c
	; nightmare
	call HandleCurse
	call CheckFaint
	ret c
	call HandleWrap
	call CheckFaint
	ret c
	; taunt
	; encore (currently not at endturn)
	; disable (currently not at endturn)
	; magnet rise
	; telekinesis
	; heal block
	; embargo
	; yawn
	call HandlePerishSong
	call CheckFaint
	ret c
	; Things below are yet to be updated to be handled in correct order
	call HandleLeppaBerry
	call HandleScreens
	call HandleSafeguard
	call HandleHealingItems
	farcall HandleAbilities

	xor a
	ld [wPlayerEndturnSwitched], a
	ld [wEnemyEndturnSwitched], a

	; these run even if the user switched at endturn
	call HandleStatusOrbs
	call HandleRoost
	call UpdateBattleMonInParty
	call LoadTileMapToTempTileMap
	jp HandleEncore

HandleEndturnBlockA:
	call SetFastestTurn
	call .do_it
	call SwitchTurn

.do_it
	; sea of fire
	; Grassy Terrain recovery
	call HasUserEndturnSwitched
	ret z
	farcall EndturnAbilitiesA
	jp HandleLeftovers
	; healer

HandleWeather:
	ld a, [wWeather]
	and a ; cp WEATHER_NONE
	ret z

	ld hl, wEndturnWeather
	dec [hl]
	ret z
	inc [hl]

	ld hl, wWeatherCount
	dec [hl]
	jp z, .ended

	; the above needs actual [wWeather] to be
	; able to time it out, but otherwise check
	; Cloud Nine
	call GetWeatherAfterCloudNine
	and a ; cp WEATHER_NONE
	ret z

	ld hl, .WeatherMessages
	call .PrintWeatherMessage
	call SetPlayerTurn
	call .ShowWeatherAnimation
	jp HandleWeatherEffects

.ended
	ld hl, .WeatherEndedMessages
	call .PrintWeatherMessage
	xor a
	ld [wWeather], a
	ret

.PrintWeatherMessage:
	ld a, [wWeather]
	dec a
	ld c, a
	ld b, 0
	add hl, bc
	add hl, bc
	ld a, [hli]
	ld h, [hl]
	ld l, a
	jp StdBattleTextBox

.ShowWeatherAnimation:
	farcall CheckBattleEffects
	ret c
	ld hl, .WeatherAnimations
	ld a, [wWeather]
	dec a
	ld b, 0
	ld c, a
	add hl, bc
	add hl, bc
	ld a, [hli]
	ld d, [hl]
	ld e, a
	xor a
	ld [wNumHits], a
	inc a
	ld [wKickCounter], a
	jp Call_PlayBattleAnim

.WeatherMessages:
	dw BattleText_RainContinuesToFall
	dw BattleText_TheSunlightIsStrong
	dw BattleText_TheSandstormRages
	dw BattleText_TheHailContinuesToFall
.WeatherEndedMessages:
	dw BattleText_TheRainStopped
	dw BattleText_TheSunlightFaded
	dw BattleText_TheSandstormSubsided
	dw BattleText_TheHailStopped
.WeatherAnimations:
	dw RAIN_DANCE
	dw SUNNY_DAY
	dw ANIM_IN_SANDSTORM
	dw ANIM_IN_HAIL

HandleWeatherEffects:
; sandstorm/hail damage, abilities like rain dish, etc.
	call SetFastestTurn
	call .do_it
	call SwitchTurn

.do_it
	call HasUserEndturnSwitched
	ret z
	farcall GetUserItemAfterUnnerve
	ld a, b
	cp HELD_SAFETY_GOGGLES
	jr z, .run_weather_abilities
	call GetWeatherAfterCloudNine
	cp WEATHER_HAIL
	call z, .HandleHail
	call GetWeatherAfterCloudNine
	cp WEATHER_SANDSTORM
	call z, .HandleSandstorm
.run_weather_abilities
	farjp RunWeatherAbilities

.HandleSandstorm
	ld a, BATTLE_VARS_SUBSTATUS3
	call GetBattleVar
	bit SUBSTATUS_UNDERGROUND, a
	ret nz
	ld a, BATTLE_VARS_ABILITY
	call GetBattleVar
	cp MAGIC_GUARD
	ret z
	cp OVERCOAT
	ret z
	cp SAND_FORCE
	ret z
	cp SAND_RUSH
	ret z
	cp SAND_VEIL
	ret z

	call CheckIfUserIsGroundType
	ret z
	call CheckIfUserIsRockType
	ret z
	call CheckIfUserIsSteelType
	ret z

	ld hl, SandstormHitsText
	call StdBattleTextBox
	call GetSixteenthMaxHP
	jp SubtractHPFromUser

.HandleHail
	ld a, BATTLE_VARS_SUBSTATUS3
	call GetBattleVar
	bit SUBSTATUS_UNDERGROUND, a
	ret nz
	ld a, BATTLE_VARS_ABILITY
	call GetBattleVar
	cp MAGIC_GUARD
	ret z
	cp OVERCOAT
	ret z
	cp SNOW_CLOAK
	ret z
	cp ICE_BODY
	ret z

	call CheckIfUserIsIceType
	ret z

	ld hl, HailHitsText
	call StdBattleTextBox
	call GetSixteenthMaxHP
	jp SubtractHPFromUser

HandleFutureSight:
	call SetFastestTurn
	call .do_it
	call SwitchTurn

.do_it
	ld hl, wPlayerFutureSightCount
	ld a, [hBattleTurn]
	and a
	jr z, .okay
	ld hl, wEnemyFutureSightCount

.okay
	ld a, [hl]
	and a
	ret z
	dec a
	ld [hl], a
	cp $1
	ret nz

	call HasUserEndturnSwitched
	jr nz, .do_future_sight

	; Future Sight misses automatically
	xor a
	ld [hl], a
	ld hl, BattleText_UsersFutureSightMissed
	jp StdBattleTextBox

.do_future_sight
	ld hl, BattleText_TargetWasHitByFutureSight
	call StdBattleTextBox

	ld a, BATTLE_VARS_MOVE
	call GetBattleVarAddr
	push af
	ld a, FUTURE_SIGHT
	ld [hl], a

	farcall UpdateMoveData
	xor a
	ld [wAttackMissed], a
	ld [wAlreadyDisobeyed], a
	ld a, $10
	ld [wTypeModifier], a
	farcall DoMove
	xor a
	ld [wCurDamage], a
	ld [wCurDamage + 1], a

	ld a, BATTLE_VARS_MOVE
	call GetBattleVarAddr
	pop af
	ld [hl], a

	call UpdateBattleMonInParty
	jp UpdateEnemyMonInParty

HandleLeftovers:
	call HasUserFainted
	ret z
	farcall GetUserItem
	call GetCurItemName
	ld a, b
	cp HELD_LEFTOVERS
	jr z, .leftovers
	cp HELD_BLACK_SLUDGE
	ret nz
	call CheckIfUserIsPoisonType
	jr z, .leftovers

	; damage instead
	call GetEighthMaxHP
	call SubtractHPFromUser
	ld hl, BattleText_UserHurtByItem
	jr .print
.leftovers
	call CheckFullHP
	ret z
	call GetSixteenthMaxHP
	call RestoreHP
	ld hl, BattleText_UserRecoveredWithItem
.print
	jp StdBattleTextBox

PreventEndturnDamage:
; returns z if residual damage at endturn is prevented
	ld a, BATTLE_VARS_ABILITY
	call GetBattleVar
	cp MAGIC_GUARD
	call nz, HasUserFainted
	call nz, HasUserEndturnSwitched
	ret

HandleLeechSeed:
	call SetFastestTurn
	call .do_it
	call SwitchTurn

.do_it
	ld a, BATTLE_VARS_SUBSTATUS4
	call GetBattleVarAddr
	bit SUBSTATUS_LEECH_SEED, [hl]
	call nz, PreventEndturnDamage
	call nz, HasOpponentFainted
	call nz, HasOpponentEndturnSwitched
	ret z

	call SwitchTurn
	xor a
	ld [wNumHits], a
	ld de, ANIM_SAP
	ld a, BATTLE_VARS_SUBSTATUS3_OPP
	call GetBattleVar
	and 1 << SUBSTATUS_FLYING | 1 << SUBSTATUS_UNDERGROUND
	call z, Call_PlayBattleAnim_OnlyIfVisible
	call SwitchTurn

	call GetEighthMaxHP
	push bc
	call SubtractHPFromUser
	pop bc
	call SwitchTurn
	farcall GetHPAbsorption
	ld a, $1
	ld [hBGMapMode], a
	ld a, BATTLE_VARS_ABILITY_OPP
	call GetBattleVar
	cp LIQUID_OOZE
	jr z, .hurt
	call RestoreHP
	jr .sap_text
.hurt
	farcall ShowEnemyAbilityActivation
	call SubtractHPFromUser
.sap_text
	call SwitchTurn
	ld hl, LeechSeedSapsText
	jp StdBattleTextBox

HandlePoison:
	call SetFastestTurn
	call .do_it
	call SwitchTurn

.do_it
	ld a, BATTLE_VARS_STATUS
	call GetBattleVar
	and 1 << PSN
	ld hl, HurtByPoisonText
	ld de, ANIM_PSN
	ret z
	jr DoPoisonBurnDamage

HandleBurn:
	call SetFastestTurn
	call .do_it
	call SwitchTurn

.do_it
	ld a, BATTLE_VARS_STATUS
	call GetBattleVar
	and 1 << BRN
	ld hl, HurtByBurnText
	ld de, ANIM_BRN
	ret z
DoPoisonBurnDamage:
	push hl
	push de
	call PreventEndturnDamage
	pop de
	pop hl
	ret z

	ld a, BATTLE_VARS_ABILITY
	call GetBattleVar
	cp POISON_HEAL
	jr nz, .got_anim
	; check if we are at full HP
	call CheckFullHP
	ret z
	ld hl, PoisonHealText
	call .do_anim
	jp RestoreHP

.do_anim
	push de
	call StdBattleTextBox
	pop de
	xor a
	ld [wNumHits], a
	call Call_PlayBattleAnim_OnlyIfVisible
	jp GetEighthMaxHP

.got_anim
	call .do_anim

	ld a, BATTLE_VARS_STATUS
	call GetBattleVar
	and 1 << BRN | 1 << TOX
	jr z, .got_damage_amount
	; Burn and Toxic does (or starts at) 1/16 damage as of Gen VII
	call GetSixteenthMaxHP

.got_damage_amount
	ld a, [hBattleTurn]
	and a
	ld hl, wPlayerToxicCount
	jr z, .got_toxic_count
	ld hl, wEnemyToxicCount
.got_toxic_count
	ld a, BATTLE_VARS_STATUS
	call GetBattleVar
	bit TOX, a
	jr z, .did_toxic
	inc [hl]
	ld a, [hl]
	ld hl, 0
.add
	add hl, bc
	dec a
	jr nz, .add
	ld b, h
	ld c, l
.did_toxic
	jp SubtractHPFromUser

HandleCurse:
	call SetFastestTurn
	call .do_it
	call SwitchTurn

.do_it
	ld a, BATTLE_VARS_SUBSTATUS1
	call GetBattleVarAddr
	bit SUBSTATUS_CURSE, [hl]
	call nz, PreventEndturnDamage
	ret z

	xor a
	ld [wNumHits], a
	ld de, ANIM_UNDER_CURSE
	call Call_PlayBattleAnim_OnlyIfVisible
	call GetQuarterMaxHP
	call SubtractHPFromUser
	ld hl, HurtByCurseText
	jp StdBattleTextBox

HandleWrap:
	call SetFastestTurn
	call .do_it
	call SwitchTurn

.do_it
	call PreventEndturnDamage
	ret z

	ld hl, wPlayerWrapCount
	ld de, wPlayerTrappingMove
	ld a, [hBattleTurn]
	and a
	jr z, .got_addrs
	ld hl, wEnemyWrapCount
	ld de, wEnemyTrappingMove

.got_addrs
	ld a, [hl]
	and a
	ret z

	ld a, BATTLE_VARS_SUBSTATUS4
	call GetBattleVar
	bit SUBSTATUS_SUBSTITUTE, a
	ret nz

	push de
	ld a, [de]
	ld [wFXAnimIDLo], a
	dec [hl]
	ld hl, BattleText_UserWasReleasedFromStringBuffer1
	jr z, .print_text

	ld a, BATTLE_VARS_SUBSTATUS3
	call GetBattleVar
	and 1 << SUBSTATUS_FLYING | 1 << SUBSTATUS_UNDERGROUND
	jr nz, .skip_anim
	call SwitchTurn
	xor a
	ld [wNumHits], a
	ld [wFXAnimIDHi], a
	predef PlayBattleAnim
	call SwitchTurn

.skip_anim
	farcall GetOpponentItemAfterUnnerve
	ld a, b
	cp HELD_BINDING_BAND
	jr nz, .no_binding_band
	call GetSixthMaxHP
	jr .subtract_hp
.no_binding_band
	call GetEighthMaxHP
.subtract_hp
	call SubtractHPFromUser
	ld hl, BattleText_UsersHurtByStringBuffer1

.print_text
	pop de
	ld a, [de]
	ld [wNamedObjectIndexBuffer], a
	call GetMoveName
	jp StdBattleTextBox

HandlePerishSong:
	call SetFastestTurn
	call .do_it
	call SwitchTurn

.do_it
	ld hl, wPlayerPerishCount
	ld a, [hBattleTurn]
	and a
	jr z, .got_count
	ld hl, wEnemyPerishCount

.got_count
	ld a, BATTLE_VARS_SUBSTATUS1
	call GetBattleVar
	bit SUBSTATUS_PERISH, a
	ret z
	dec [hl]
	ld a, [hl]
	ld [wd265], a
	push af
	ld hl, PerishCountText
	call StdBattleTextBox
	pop af
	ret nz
	ld a, BATTLE_VARS_SUBSTATUS1
	call GetBattleVarAddr
	res SUBSTATUS_PERISH, [hl]
	ld a, [hBattleTurn]
	and a
	jr nz, .kill_enemy
	ld hl, wBattleMonHP
	xor a
	ld [hli], a
	ld [hl], a
	ld hl, wPartyMon1HP
	ld a, [wCurBattleMon]
	call GetPartyLocation
	xor a
	ld [hli], a
	ld [hl], a
	ret

.kill_enemy
	ld hl, wEnemyMonHP
	xor a
	ld [hli], a
	ld [hl], a
	ld a, [wBattleMode]
	dec a
	ret z
	ld hl, wOTPartyMon1HP
	ld a, [wCurOTMon]
	call GetPartyLocation
	xor a
	ld [hli], a
	ld [hl], a
	ret

HandleLeppaBerry:
	call SetFastestTurn
	call .do_it
	call SwitchTurn

.do_it
	call HasUserEndturnSwitched
	ret z
	farcall GetUserItemAfterUnnerve
	ld a, b
	cp HELD_RESTORE_PP
	ret nz
	call PreparePPRestore
	call GetZeroPPMove
	ret z
	push bc
	call ConsumeUserItem
	pop bc
	jp LeppaRestorePP

HandleScreens:
	call CheckSpeed
	jr nz, .enemy_first

	call .CheckPlayer
	jr .CheckEnemy

.enemy_first
	call .CheckEnemy
.CheckPlayer:
	call SetPlayerTurn
	ld de, .Your
	call .Copy
	ld hl, wPlayerScreens
	ld de, wPlayerLightScreenCount
	jr .TickScreens

.CheckEnemy:
	call SetEnemyTurn
	ld de, .Enemy
	call .Copy
	ld hl, wEnemyScreens
	ld de, wEnemyLightScreenCount

.TickScreens:
	bit SCREENS_LIGHT_SCREEN, [hl]
	call nz, .LightScreenTick
	bit SCREENS_REFLECT, [hl]
	call nz, .ReflectTick
	ret

.Copy:
	ld hl, wStringBuffer1
	jp CopyName2

.Your:
	db "Your@"
.Enemy:
	db "Foe@"


.LightScreenTick:
	ld a, [de]
	dec a
	ld [de], a
	ret nz
	res SCREENS_LIGHT_SCREEN, [hl]
	push hl
	push de
	ld hl, BattleText_PkmnLightScreenFell
	call StdBattleTextBox
	pop de
	pop hl
	ret

.ReflectTick:
	inc de
	ld a, [de]
	dec a
	ld [de], a
	ret nz
	res SCREENS_REFLECT, [hl]
	ld hl, BattleText_PkmnReflectFaded
	jp StdBattleTextBox

HandleSafeguard:
	call CheckSpeed
	jr z, .player_first

	call .CheckEnemy
.CheckPlayer:
	ld a, [wPlayerScreens]
	bit SCREENS_SAFEGUARD, a
	ret z
	ld hl, wPlayerSafeguardCount
	dec [hl]
	ret nz
	res SCREENS_SAFEGUARD, a
	ld [wPlayerScreens], a
	xor a
	jr .print

.player_first
	call .CheckPlayer
.CheckEnemy:
	ld a, [wEnemyScreens]
	bit SCREENS_SAFEGUARD, a
	ret z
	ld hl, wEnemySafeguardCount
	dec [hl]
	ret nz
	res SCREENS_SAFEGUARD, a
	ld [wEnemyScreens], a
	ld a, $1

.print
	ld [hBattleTurn], a
	ld hl, BattleText_SafeguardFaded
	jp StdBattleTextBox

HandleHealingItems: ; 3dcf9
	call SetFastestTurn
	call .do_it
	call SwitchTurn

.do_it
	; runs instantly whenever possible, so don't prevent usage
	; even if the user endturn switched
	call HasUserFainted
	ret z
	call HandleHPHealingItem
	call UseHeldStatusHealingItem
	call HandleStatBoostBerry
	jp UseConfusionHealingItem

HandleStatusOrbs:
	call SetFastestTurn
	; Done for target to simplify checks so invert
	; turn
	call SwitchTurn
	call .do_it
	call SwitchTurn

.do_it
	farcall GetOpponentItemAfterUnnerve
	ld a, b
	cp HELD_SELF_BRN
	ld b, 1 << BRN
	jr z, .burn
	cp HELD_SELF_PSN
	ld b, 1 << PSN | 1 << TOX
	jr z, .poison
	ret
.poison
	push bc
	ld b, 0
	farcall CanPoisonTarget
	pop bc
	ret nz
	ld de, ANIM_PSN
	ld hl, BadlyPoisonedText
	jr .do_status
.burn
	push bc
	ld b, 0
	farcall CanBurnTarget
	pop bc
	ret nz
	ld de, ANIM_BRN
	ld hl, WasBurnedText
	; fallthrough
.do_status
	push hl
	ld a, BATTLE_VARS_STATUS_OPP
	call GetBattleVarAddr
	ld [hl], b
	xor a
	ld [wNumHits], a
	farcall PlayOpponentBattleAnim
	call RefreshBattleHuds
	pop hl
	jp StdBattleTextBox

HandleRoost:
	call SetFastestTurn
	call .do_it
	call SwitchTurn

.do_it
	ld a, BATTLE_VARS_SUBSTATUS4
	call GetBattleVarAddr
	bit SUBSTATUS_ROOST, [hl]
	res SUBSTATUS_ROOST, [hl]
	ret z

	ld a, [hBattleTurn]
	and a
	ld hl, wBattleMonType1
	jr z, .got_types
	ld hl, wEnemyMonType1
.got_types
	; Check which type is ???
	ld a, [hl]
	cp UNKNOWN_T
	jr z, .got_target
	inc hl
	ld a, [hl]
	cp UNKNOWN_T
	jr nz, .aerliate
.got_target
	ld [hl], FLYING
	ret
.aerliate
	; Set Flying types on both
	ld a, FLYING
	ld [hld], a
	ld [hl], a
	ret