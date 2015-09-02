-- |  Drums of the Korg TR-808 drum machine (recoded from 	Iain McCurdy).
module Csound.Catalog.Drum.Tr808(
	TrSpec(..),

	bass, snare, openHiHat, closedHiHat, 
	lowTom, midTom, highTom, cymbal, claves, rimShot,
	maraca, highConga, midConga, lowConga,

	-- * Generic
	bass', bdSpec, snare', snSpec, openHiHat', ohSpec, closedHiHat', chSpec,
	lowTom', ltSpec, midTom', mtSpec, highTom', htSpec, cymbal', cymSpec, claves', clSpec, rimShot', rimSpec,
	maraca', marSpec, highConga', hcSpec, midConga', mcSpec, lowConga', lcSpec,

	-- * Metronome
	ticks, nticks,

	-- * Sampler
	bd, sn, ohh, chh, htom, mtom, ltom, cym, cl, rim, mar, hcon, mcon, lcon,

	-- ** Generic
	bd', sn', ohh', chh', htom', mtom', ltom', cym', cl', rim', mar', hcon', mcon', lcon'

) where

import Csound.Base
import Csound.Sam

-- don't forget to update the gen-opcodes and the hackage opcodes

rndAmp :: Sig -> SE Sig
rndAmp a = do
	k <- birnd 0.09
	return $ a * (1 + sig k)

data TrSpec = TrSpec {
	  trDur 	:: D
	, trTune 	:: D
	, trCps 	:: D
	, trRnd     :: Maybe D
	}

cpsSpec cps = TrSpec 
	{ trDur   = 0.8
	, trTune  = 0
	, trCps   = cps 
	, trRnd   = Just 0.085 }


rndVal :: D -> D -> D -> SE D
rndVal total amount x = do
	k <- birnd amount 
	return $ x  + k * total

rndDur amt x = rndVal x amt x
rndCps amt x = rndVal x (amt / 10) x
rndTune amt x = rndVal 0.7 amt x

rndSpec ::TrSpec -> SE TrSpec
rndSpec spec = do
	dur  <- rndDur'
	tune <- rndTune'
	cps  <- rndCps'
	return $ spec 
		{ trDur  = dur 
		, trTune = tune
		, trCps  = cps }
	where 
		rndDur'  = (maybe return rndDur $ (trRnd spec)) $ trDur spec
		rndTune' = (maybe return rndTune $ (trRnd spec)) $ trTune spec
		rndCps'  = (maybe return rndCps $ (trRnd spec)) $ trCps spec

bdSpec = TrSpec 
	{ trDur   = 0.95
	, trTune  = 1
	, trCps   = 55 
	, trRnd   = Just 0.05 }

addDur' dt x = xtratim dt >> return x
addDur = addDur' 0.1

bass = bass' bdSpec

bass' spec = pureBass' =<< rndSpec spec

pureBass' :: TrSpec -> SE Sig
pureBass' spec = rndAmp =<< addDur amix
	where
		dur = trDur spec
		cps = trCps spec

		kmul  = transegr [0.2, dur * 0.5, -15, 0.01, dur * 0.5, 0, 0] dur 0 0
		kbend = transegr [0.5, 1.2, -4, 0, 1, 0, 0] dur 0 0
		asig  = gbuzz 0.5 (sig cps * semitone kbend) 20 1 kmul cosine
		aenv  = transeg [1, dur - 0.004, -6, 0]
		att   = linseg [0, 0.004, 1]
		asig1 = asig * aenv * att

		aenv1 = linseg [1, 0.07, 0]
		acps  = expsega [8 * cps,0.07,0.001]
		aimp  = oscili  aenv1 acps sine
		amix  = asig1 * 0.7 +  aimp * 0.25

snSpec = cpsSpec 342
	
snare = snare' snSpec

snare' spec = pureSnare' =<< rndSpec spec

-- sound consists of two sine tones, an octave apart and a noise signal		
pureSnare' :: TrSpec -> SE Sig
pureSnare' spec = rndAmp =<< addDur =<< (apitch + anoise)
	where	
		dur 	= trDur  spec
		tune    = trTune spec
		cps     = trCps  spec

		iNseDur = dur * 0.3
		iPchDur  = dur * 0.1

		-- sine tones component
		aenv1 	= expsegr [1, iPchDur, 0.0001] iNseDur 0.0001
		apitch1 = rndOsc (sig cps)
		apitch2 = rndOsc (0.5 * sig cps)
		apitch  = mul (0.75 * aenv1) (apitch1 + apitch2)

		-- noise component		
		aenv2	= expon 1 iNseDur 0.0005
		kcf 	= expsegr [5000, 0.1, 3000] iNseDur 0.0001
		anoise	= mul aenv2 $ do
			x <- noise 0.75 0
			return $ blp kcf $ bhp 1000 $ bbp (10000 * octave (sig tune)) 10000 x

ohSpec = cpsSpec 296
chSpec = cpsSpec 296

openHiHat = openHiHat' ohSpec
closedHiHat = closedHiHat' chSpec

openHiHat' :: TrSpec -> SE Sig
openHiHat' spec = genHiHat (linsegr [1, (dur/2) - 0.05, 0.1, 0.05, 0] dur 0) spec
	where dur = trDur spec

closedHiHat' :: TrSpec -> SE Sig
closedHiHat' spec = genHiHat (expsega [1, (dur / 2), 0.001]) spec
	where dur = trDur spec

-- sound consists of 6 pulse oscillators mixed with a noise component
-- cps = 296
genHiHat :: Sig -> TrSpec -> SE Sig
genHiHat pitchedEnv spec = rndAmp =<< addDur =<< (amix1 + anoise)
	where 	
		dur 	= trDur  spec
		tune    = trTune spec
		cps     = trCps  spec

		halfDur = dur * 0.5		

		-- pitched element
		harmonics = [1.0, 0.962, 1.233, 1.175,1.419, 2.821]		
		amix 	= mul 0.5 $ fmap sum $ mapM (rndPw 0.25 . sig . (* (cps * octave tune))) harmonics
		amix1   = mul pitchedEnv $ at (\asig -> bhp 5000 $ bhp 5000 $ reson asig (5000 * octave (sig tune)) 5000 `withD` 1) amix

		-- noise element
		kcf		= expseg [20000, 0.7, 9000, halfDur-0.1, 9000] 
		anoise 	= mul pitchedEnv $ do
			x <- noise 0.8 0
			return $ bhp 8000 $ blp kcf x

htSpec = cpsSpec 200
mtSpec = cpsSpec 133
ltSpec = cpsSpec 90

lowTom = lowTom' ltSpec
midTom = midTom' mtSpec
highTom = highTom' htSpec 

-- cps = 200
highTom' :: TrSpec -> SE Sig
highTom' = genTom 0.5 (400, 100, 1000)

-- cps = 133
midTom' :: TrSpec -> SE Sig
midTom' = genTom 0.6 (400, 100, 600)

-- cps =  90
lowTom' :: TrSpec -> SE Sig
lowTom' = genTom 0.6 (40, 100, 600)

genTom :: D -> (Sig, Sig, Sig) -> TrSpec -> SE Sig
genTom durDt (resonCf, hpCf, lpCf) spec = rndAmp =<< addDur =<< (asig + anoise)
	where	
		dur 	= trDur  spec
		tune    = trTune spec
		cps     = trCps  spec

		ifrq 	= cps * octave tune
		halfDur = durDt * dur

		-- sine tone signal
		aAmpEnv	= transeg [1, halfDur, -10, 0.001]
		afmod	= expsega  [5, 0.125/ifrq, 1]
		asig  	= mul (-aAmpEnv) $ rndOsc (sig ifrq * afmod)

		-- noise signal
		aEnvNse = transeg [1, halfDur, -6 , 0.001]
		otune = sig $ octave tune
		anoise  = mul aEnvNse $ do 
			x <- noise 1 0.4
			return $ blp (lpCf * otune) $ bhp (hpCf * otune) $ reson x (resonCf * otune) 800 `withD` 1

cymSpec = cpsSpec 296

cymbal = cymbal' cymSpec

-- sound consists of 6 pulse oscillators mixed with a noise component
-- cps = 296
cymbal' :: TrSpec -> SE Sig
cymbal' spec = rndAmp =<< addDur =<< (fmap (amix1 + ) anoise)
	where 
		dur 	= trDur  spec
		tune    = trTune spec
		cps     = trCps  spec

		fullDur = dur * 2

		-- pitched element
		harmonics = [1.0, 0.962, 1.233, 1.175,1.419, 2.821]
		aenv 	= expon 1 fullDur 0.0001
		amix 	= mul 0.5 $ sum $ fmap (pw 0.25 . sig . (* (cps * octave tune))) harmonics
		amix1   = mul aenv $ blp 12000 $ blp 12000 $ bhp 10000 $ reson amix (5000 * octave (sig tune)) 5000 `withD` 1

		-- noise element
		aenv2   = expsega [1,0.3,0.07,fullDur-0.1,0.00001]
		kcf		= expseg [14000, 0.7, 7000, fullDur-0.1, 5000] 
		anoise 	= mul aenv2 $ do
			x <- noise 0.8 0
			return $ bhp 8000 $ blp kcf x

clSpec = cpsSpec 2500

claves = claves' clSpec

-- cps = 2500
claves' :: TrSpec -> SE Sig
claves' spec = rndAmp =<< addDur =<< asig
	where
		dur 	= trDur  spec
		tune    = trTune spec
		cps     = trCps  spec

		ifrq = cps * octave tune
		dt   = 0.045 * dur
		aenv = expsega	[1, dt, 0.001]
		afmod = expsega	[3,0.00005,1]
		asig = mul (- 0.4 * (aenv-0.001)) $ rndOsc (sig ifrq * afmod)

getAccent :: Int -> [D]
getAccent n = 1 : replicate (n - 1) 0.5

-- | Metronome with a chain of accents.
-- A typical 7/8 for example:
--
-- > dac $ nticks [3, 2, 2] (135 * 2)
nticks :: [Int] -> Sig -> Sig
nticks ns = genTicks (cycleE $ ns >>= getAccent)	

-- | Metronome.
--
-- > ticks n bpm
ticks :: Int -> Sig -> Sig
ticks n 
	| n <= 1 	= genTicks (devt 0.5)
	| otherwise = genTicks (cycleE $ getAccent n)

genTicks :: (Tick -> Evt D) -> Sig -> Sig
genTicks f x = mul 3 $ mlp 4000 0.1 $ 
	sched (\amp -> mul (sig amp) $ rimShot' (TrSpec (amp + 1) 0 (1200 * (amp + 0.5)) (Just 0.05))) $ 
	withDur 0.5 $ f $ metro (x / 60)

rimSpec = cpsSpec 1700

rimShot = rimShot' rimSpec

rimShot' spec = pureRimShot' =<< rndSpec spec

-- cps = 1700
pureRimShot' :: TrSpec -> SE Sig
pureRimShot' spec = rndAmp =<< addDur =<< (mul 0.8 $ aring + anoise)
	where
		dur 	= trDur  spec
		tune    = trTune spec
		cps     = trCps  spec

		fullDur = 0.027 * dur

		-- ring
		aenv1 =	expsega	[1,fullDur,0.001]
		ifrq1 =	sig $ cps * octave tune		
		aring = mul (0.5 * (aenv1 - 0.001)) $ at (bbp ifrq1 (ifrq1 * 8)) $ rndOscBy tabTR808RimShot ifrq1

		-- noise
		aenv2 =	expsega	[1, 0.002, 0.8, 0.005, 0.5, fullDur-0.002-0.005, 0.0001]
		kcf	  = expsegr [4000, fullDur, 20] fullDur 20
		anoise = mul (aenv2 - 0.001) $ fmap (blp kcf) $ noise 1 0

		tabTR808RimShot = setSize 1024 $ sines [0.971,0.269,0.041,0.054,0.011,0.013,0.08,0.0065,0.005,0.004,0.003,0.003,0.002,0.002,0.002,0.002,0.002,0.001,0.001,0.001,0.001,0.001,0.002,0.001,0.001]

cowSpec = cpsSpec 562

cowbell = cowbell' cowSpec

-- cps = 562
cowbell' ::  TrSpec -> SE Sig
cowbell' spec = rndAmp =<< addDur =<< ares
	where
		dur 	= trDur  spec
		tune    = trTune spec
		cps     = trCps  spec

		ifrq1 = sig $ cps * octave tune
		ifrq2 = 1.5 * ifrq1
		fullDur = 0.7 * dur
		ishape	= -30
		ipw  	= 0.5
		kenv1	= transeg	[1,fullDur*0.3,ishape,0.2, fullDur*0.7,ishape,0.2]
		kenv2	= expon	1 fullDur 0.0005
		kenv    = kenv1 * kenv2
		amix    = mul 0.65 $ rndPw 0.5 ifrq1 + rndPw 0.5 ifrq2
		iLPF2	= 10000
		kcf		= expseg [12000,0.07,iLPF2,1,iLPF2]
		alpf    = at (blp kcf) amix
		abpf    = at (\x -> reson x ifrq2 25) amix
		ares    = mul (0.08 * kenv) $ at dcblock2 $ mul (0.06 * kenv1) abpf + mul 0.5 alpf + mul 0.9 amix 

-- TODO clap

{-
instr	112	;CLAP
	krelease	release				;SENSE RELEASE OF THIS NOTE ('1' WHEN RELEASED, OTHERWISE ZERO)   
	chnset	1-krelease,"Act12"              	;TURN ON ACTIVE LIGHT WHEN NOTE STARTS, TURN IT OFF WHEN NOTE ENDS
	iTimGap	=	0.01				;GAP BETWEEN EVENTS DURING ATTACK PORTION OF CLAP
	idur1  	=	0.02				;DURING OF THE THREE INITIAL 'CLAPS'
	idur2  	=	2*i(gkdur12)			;DURATION OF THE FOURTH, MAIN, CLAP
	idens  	=	8000				;DENSITY OF THE NOISE SIGNAL USED TO FORM THE CLAPS
	iamp1  	=	0.5				;AMPLITUDE OF AUDIO BEFORE BANDPASS FILTER IN OUTPUT
	iamp2  	=	1				;AMPLITUDE OF AUDIO AFTER BANDPASS FILTER IN OUTPUT
	if frac(p1)==0 then				;IF THIS IS THE INITIAL NOTE (p1 WILL BE AN INTEGER)
	 ;	        del.  dur  env.shape
	 event_i	"i", p1+0.1, 0,          idur1, p4	;CALL THIS INSTRUMENT 4 TIMES. ADD A FRACTION ONTO p1 TO BE ABLE TO DIFFERENTIATE THESE SUBSEQUENT NOTES
	 event_i	"i", p1+0.1, iTimGap,    idur1, p4
	 event_i	"i", p1+0.1, iTimGap*2,  idur1, p4
	 event_i	"i", p1+0.1, iTimGap*3,  idur2, p4
	else
	 kenv	transeg	1,p3,-25,0				;AMPLITUDE ENVELOPE
	 iamp	random	0.7,1					;SLIGHT RANDOMISATION OF AMPLITUDE	
	 anoise	pinkish	kenv*iamp
	 iBPF   	=	1100*octave(i(gktune12))	;FREQUENCY OF THE BANDPASS FILTER
	 ibw    	=	2000*octave(i(gktune12))	;BANDWIDTH OF THE BANDPASS FILTER
	 iHPF   	=	1000				;FREQUENCY OF A HIGHPASS FILTER
	 iLPF   	=	1				;SCALER FOR FREQUENCY OF A LOWPASS FILTER
	 kcf	expseg	8000,0.07,1700,1,800,2,500,1,500	;CREATE CUTOFF FREQUENCY ENVELOPE
	 asig	butlp	anoise,kcf*iLPF				;LOWPASS FILTER THE SOUND
	 asig	buthp	asig,iHPF				;HIGHPASS FILTER THE SOUND
	 ares	reson	asig,iBPF,ibw,1				;BANDPASS FILTER THE SOUND (CREATE A NEW SIGNAL)
	 asig	dcblock2	(asig*iamp1)+(ares*iamp2)	;MIX BANDPASS FILTERED AND NON-BANDPASS FILTERED SOUND ELEMENTS
	 asig	=	asig*p4*i(gklevel12)*1.75*gklevel	;SCALE AMPLITUDE
	 aL,aR	pan2	asig,i(gkpan12)				;PAN MONOPHONIC SIGNAL
		outs	aL,aR					;SEND AUDIO TO OUTPUTS
	endif
endin
-}

{-
clap ::  D -> D -> D -> Sig
clap dur tune cps =
	where
		iTimGap	=	0.01
-}

marSpec = cpsSpec 450

maraca = maraca' marSpec

maraca' ::  TrSpec -> SE Sig
maraca' spec = rndAmp =<< addDur =<< anoise
	where
		dur 	= trDur  spec
		tune    = trTune spec
		cps     = trCps  spec

		fullDur = 0.07* dur
		otune   = sig $ octave tune
		iHPF 	= limit	(6000 * otune) 20 (sig getSampleRate / 2)
		iLPF 	= limit	(12000 * otune) 20 (sig getSampleRate / 3)
		aenv	= expsega [0.4,0.014* dur,1,0.01 * dur, 0.05, 0.05 * dur, 0.001]
		anoise  = mul aenv $ fmap (blp iLPF . bhp iHPF) $ noise 0.75 0

hcSpec = cpsSpec 420
mcSpec = cpsSpec 310
lcSpec = cpsSpec 227

highConga = highConga' hcSpec
midConga  = midConga'  mcSpec
lowConga  = lowConga'  lcSpec 

-- high conga
-- cps = 420
highConga' :: TrSpec -> SE Sig
highConga' = genConga 0.22

-- cps = 310
midConga' :: TrSpec -> SE Sig
midConga' = genConga 0.33

-- cps = 227
lowConga' :: TrSpec -> SE Sig
lowConga' = genConga 0.41

genConga :: D -> TrSpec -> SE Sig
genConga dt spec = rndAmp =<< addDur =<< asig
	where
		dur 	= trDur  spec
		tune    = trTune spec
		cps     = trCps  spec

		ifrq = cps * octave tune
		fullDur = dt * dur
		aenv = transeg [0.7,1/ifrq,1,1,fullDur,-6,0.001]
		afmod = expsega [3,0.25/ifrq,1]
		asig = mul (-0.25 * aenv) $ rndOsc (sig ifrq * afmod)


-----------------------------------------------------
-- sampler

mkSam = limSam 1

bd :: Sam
bd = mkSam bass

sn :: Sam
sn = mkSam snare

ohh :: Sam
ohh = mkSam openHiHat

chh :: Sam
chh = mkSam closedHiHat 

htom :: Sam
htom = mkSam highTom

mtom :: Sam
mtom = mkSam midTom

ltom :: Sam
ltom = mkSam lowTom

cym :: Sam
cym = mkSam cymbal

cl :: Sam
cl = mkSam claves

rim :: Sam
rim = mkSam rimShot

mar :: Sam
mar = mkSam maraca

hcon :: Sam
hcon = mkSam highConga

mcon :: Sam
mcon = mkSam midConga

lcon :: Sam
lcon = mkSam lowConga

-- generic sam

mkSam' f spec = mkSam $ f spec

bd' :: TrSpec -> Sam
bd' = mkSam' bass'

sn' :: TrSpec -> Sam
sn' = mkSam' snare'

ohh' :: TrSpec -> Sam
ohh' = mkSam' openHiHat'

chh' :: TrSpec -> Sam
chh' = mkSam' closedHiHat'

htom' :: TrSpec -> Sam
htom' = mkSam' highTom'

mtom' :: TrSpec -> Sam
mtom' = mkSam' midTom'

ltom' :: TrSpec -> Sam
ltom' = mkSam' lowTom'

cym' :: TrSpec -> Sam
cym' = mkSam' cymbal'

cl' :: TrSpec -> Sam
cl' = mkSam' claves'

rim' :: TrSpec -> Sam
rim' = mkSam' rimShot'

mar' :: TrSpec -> Sam
mar' = mkSam' maraca'

hcon' :: TrSpec -> Sam
hcon' = mkSam' highConga'

mcon' :: TrSpec -> Sam
mcon' = mkSam' midConga'

lcon' :: TrSpec -> Sam
lcon' = mkSam' lowConga'


