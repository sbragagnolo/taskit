Class {
	#name : #TKTSameImageArchetypeTestBuilding,
	#superclass : #ParametrizedTestCase,
	#instVars : [
		'archetype',
		'deployer',
		'session'
	],
	#category : #TaskItForkIt
}

{ #category : #tests }
TKTSameImageArchetypeTestBuilding class >> testParameters [
	^ ParametrizedTestMatrix new
		forSelector: #archetype
			addOptions:
			{TKTArchetype pharoCurrent.
			TKTArchetype pharo70.
			TKTArchetype pharo80};
		yourself
]

{ #category : #tests }
TKTSameImageArchetypeTestBuilding >> archetype: anArchetype [
	archetype := anArchetype 
]

{ #category : #tests }
TKTSameImageArchetypeTestBuilding >> setUp [
	super setUp.
	session := Smalltalk session.
	deployer := TKTDeployer default.
]

{ #category : #tests }
TKTSameImageArchetypeTestBuilding >> tearDown [
	session = Smalltalk session
		ifTrue: [ (TKTSystem rm
				option: '-rf';
				argument: (#/ asFileReference / #tmp / archetype name) fullName;
				future) synchronizeTimeout: 5 seconds.
			(TKTSystem rm
				option: '-rf';
				argument: ('pharo-local' asFileReference / #forking) fullName;
				future) synchronizeTimeout: 5 seconds ]
]

{ #category : #tests }
TKTSameImageArchetypeTestBuilding >> testArchetypeIsDeleteOnQuit [
	self assert: archetype deleteOnQuit
]

{ #category : #tests }
TKTSameImageArchetypeTestBuilding >> testArchetypeIsQuitOnFinalization [
	self assert: archetype quitOnFinalization.
]

{ #category : #tests }
TKTSameImageArchetypeTestBuilding >> testCommunicationStonHasNoDependancies [
	self assert: archetype dependancies size equals: 0
]

{ #category : #tests }
TKTSameImageArchetypeTestBuilding >> testDeployDeploysAFunctionalEnvironment [
	| destination deployed |
	destination := (#/ asFileReference / #tmp / archetype name
		/ UUID new asString)
		ensureCreateDirectory;
		yourself.
	deployed := deployer deploy: archetype at: destination.
	self assert: deployed vmFolder exists.
	self assert: deployed imageFile exists.
	self assert: deployed changesFile exists.
	self assert: deployed sourcesFile exists.

	

]

{ #category : #tests }
TKTSameImageArchetypeTestBuilding >> testTheArchetypeIsHeadless [
	self assert: archetype isHeadless
]

{ #category : #tests }
TKTSameImageArchetypeTestBuilding >> testTheArchetypeIsNotHeadless [
	archetype headless: false.
	self deny: archetype isHeadless
]

{ #category : #tests }
TKTSameImageArchetypeTestBuilding >> testTheArchetypeUsesCopyImageProvider [
	self
		assert: (deployer imageProvider isKindOf: TKTImageProvider)
]

{ #category : #tests }
TKTSameImageArchetypeTestBuilding >> testTheArchetypeVmProviderIsSameVmProvider [
	self assert: (deployer vmProvider isKindOf: TKTVMProvider)
]

{ #category : #tests }
TKTSameImageArchetypeTestBuilding >> testTheSameVmProviderUsesTheSameVm [
	self
		assert:
			(deployer vmProvider
				resolve: #current
				forImage: #current
				architecture: 32) first
		equals: Smalltalk vmDirectory asFileReference
]