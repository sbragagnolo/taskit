"
The file oriented deployer is based on th fact that the resource provider will provide URLS and that the installation will be done by downloading already bootstrapped images as well as already compiled VMs.

Since is file based, it integrates as well a cache. that will be nice to extract to other object in the near future. 

This responsibility allows to redefine how to interpret the provided resources realted to an archetype. 
"
Class {
	#name : #TKTFileOrientedDeployer,
	#superclass : #Object,
	#instVars : [
		'backend',
		'provider'
	],
	#category : #'TaskItForkIt-ImageBuilding'
}

{ #category : #accessing }
TKTFileOrientedDeployer class >> default [
	^ self new
		backend: TKTSystemBackend new;
		yourself
]

{ #category : #accessing }
TKTFileOrientedDeployer class >> pharoScript [
	^ '
#!/usr/bin/env bash
# some magic to find out the real location of this script dealing with symlinks
DIR=`readlink "$0"` || DIR="$0";
DIR=`dirname "$DIR"`;
cd "$DIR"
DIR=`pwd`
cd - > /dev/null
# disable parameter expansion to forward all arguments unprocessed to the VM
set -f
# run the VM and pass along all arguments as is
"$DIR"/"pharo-vm/Pharo.app/Contents/MacOS/Pharo" --headless "$@"'
]

{ #category : #accessing }
TKTFileOrientedDeployer class >> pharoUiScript [
	^ '#!/usr/bin/env bash
# some magic to find out the real location of this script dealing with symlinks
DIR=`readlink "$0"` || DIR="$0";
DIR=`dirname "$DIR"`;
cd "$DIR"
DIR=`pwd`
cd - > /dev/null
# disable parameter expansion to forward all arguments unprocessed to the VM
set -f
# run the VM and pass along all arguments as is
"$DIR"/"pharo-vm/Pharo.app/Contents/MacOS/Pharo" "$@"'
]

{ #category : #folder }
TKTFileOrientedDeployer >> archetypesDestination [
	^ self baseFolder / #archetypes
]

{ #category : #folder }
TKTFileOrientedDeployer >> archetypesDestinationFor: anArchetype [
	^ self archetypesDestination / anArchetype name
]

{ #category : #folder }
TKTFileOrientedDeployer >> archetypesStonDestinationFor: anArchetype [
	^ (self archetypesDestinationFor: anArchetype) / anArchetype name
		, 'ston'
]

{ #category : #accessing }
TKTFileOrientedDeployer >> backend: aTKTSystemBackend [ 
	backend := aTKTSystemBackend
]

{ #category : #'deploy destination' }
TKTFileOrientedDeployer >> backupCurrentImage [
	| session sources |
	session := Smalltalk session.
	Smalltalk image
		backupTo: (self currentCacheFolder / 'Pharo') fullName.
	sources := (Smalltalk imageDirectory entries
		detect: [ :f | f basename endsWith: '.sources' ]) asFileReference.
	sources copyTo: self currentCacheFolder / sources basename.
	session ~= Smalltalk session
		ifTrue: [ UIManager default spawnNewProcess.
			Processor activeProcess terminate ].
	^ {(self currentCacheFolder / sources basename).
	(self currentCacheFolder / 'Pharo.image').
	(self currentCacheFolder / 'Pharo.changes')}
]

{ #category : #folder }
TKTFileOrientedDeployer >> baseFolder [
	^ backend workingDirectory / 'pharo-local' / #forking
]

{ #category : #'system calls' }
TKTFileOrientedDeployer >> copy: aFileReference to: aDestination [
	^ backend copy: aFileReference to: aDestination.

]

{ #category : #accessing }
TKTFileOrientedDeployer >> createScript: ref with: content [
	ref ensureCreateFile.
	(ZnNewLineWriterStream on: ref writeStream)
		forPlatformLineEnding;
		nextPutAll: content;
		close.
	(TKTSystem chmod
		option: '+x';
		argument: ref fullName;
		future) synchronizeTimeout: 5 seconds
]

{ #category : #folder }
TKTFileOrientedDeployer >> currentCacheFolder [
	^ self baseFolder / #current
]

{ #category : #folder }
TKTFileOrientedDeployer >> defaultDeployFolder [
	^ self baseFolder / #deployCache
]

{ #category : #accessing }
TKTFileOrientedDeployer >> deploy: anArchetype at: location [
	| deployed |
	self createScript: location / 'pharo' with: self class pharoScript.
	self
		createScript: location / 'pharo-ui'
		with: self class pharoUiScript.
	anArchetype parent
		ifNil: [ self deployFiles: anArchetype at: location ]
		ifNotNil: [ self deploy: anArchetype parent at: location ].
	deployed := TKTDeployed new
		initializeWithLocation: location
			archetype: anArchetype
			andBackend: backend;
		yourself.
	self updateDeployed: deployed using: self.
	^ deployed
]

{ #category : #folder }
TKTFileOrientedDeployer >> deployAtDefaultLocation: anArchetype [
	| id |
	id := UUID new asString.
	(self defaultDeployFolder / anArchetype name / id)
		ensureCreateDirectory.
	^ self
		deploy: anArchetype
		at: self defaultDeployFolder / anArchetype name / id
]

{ #category : #accessing }
TKTFileOrientedDeployer >> deployFiles: anArchetype at: location [
	self ensureInstallationDirectoryFor: anArchetype.
	self
		installVm:
			(provider
				resolveVM: anArchetype vmSelector
				forImage: anArchetype imageSelector
				architecture: anArchetype architectureSelector
				using: self)
		at: location.
	self
		installImageAndSource:
			(provider
				resolvePharoBundle: anArchetype vmSelector
				forImage: anArchetype imageSelector
				architecture: anArchetype architectureSelector
				using: self)
		at: location
]

{ #category : #folder }
TKTFileOrientedDeployer >> ensureInstallationDirectoryFor: anArchetype [
	(self archetypesDestinationFor: anArchetype) exists
		ifTrue: [ backend rm: (self archetypesDestinationFor: anArchetype) ].
	(self archetypesDestinationFor: anArchetype) ensureCreateDirectory
]

{ #category : #getting }
TKTFileOrientedDeployer >> fetchBundle: aZnUrl [
	| expectedLocation |
	expectedLocation := aZnUrl segments allButFirst
		inject: self imageFolder
		into: [ :acc :each | acc / (each copyReplaceAll: '.zip' with: '') ].
	expectedLocation exists
		ifFalse:
			[ self privateDownloadBundle: aZnUrl at: expectedLocation ].
	^ expectedLocation entries
]

{ #category : #fetch }
TKTFileOrientedDeployer >> fetchVm: aZnUrl [
	| expectedLocation |
	expectedLocation := (aZnUrl segments allButFirst
		inject: self vmFolder
		into: [ :acc :each | acc / (each copyReplaceAll: '.zip' with: '') ])
		/ 'pharo-vm'.
	expectedLocation exists
		ifFalse: [ expectedLocation ensureCreateDirectory.
			backend downloadAndUnzip: aZnUrl at: expectedLocation ].
	backend chmod: expectedLocation flag: '+x'.
	^ expectedLocation
]

{ #category : #folder }
TKTFileOrientedDeployer >> imageFolder [
	^ self baseFolder / #image
]

{ #category : #getting }
TKTFileOrientedDeployer >> initialize [
	super initialize.
	provider := TKTResourceProvider new
]

{ #category : #accessing }
TKTFileOrientedDeployer >> installImageAndSource: bundle at: location [
	| imageChangesAndSourceFileReferenceArray |
	imageChangesAndSourceFileReferenceArray := bundle = #current
		ifTrue: [ self resolveCurrentImageAnChangesFile ]
		ifFalse: [ self fetchBundle: bundle ].
	backend copyAll: imageChangesAndSourceFileReferenceArray to: location
]

{ #category : #accessing }
TKTFileOrientedDeployer >> installVm: aVm at: location [
	| vmFolderReference |
	vmFolderReference := aVm = #current
		ifTrue: [ self resolveCurrentVM ]
		ifFalse: [ self fetchVm: aVm ].
	backend installSymlinkTo: vmFolderReference at: location
]

{ #category : #accessing }
TKTFileOrientedDeployer >> platformName [
	^ OSPlatform current isUnix
		ifTrue: [ 'linux' ]
		ifFalse: [ OSPlatform current isWindows
				ifTrue: [ 'win' ]
				ifFalse: [ 'mac' ] ]
]

{ #category : #getting }
TKTFileOrientedDeployer >> privateDownloadBundle: aZnUrl at: expectedLocation [
	expectedLocation exists
		ifTrue: [ backend rm: expectedLocation ].
	expectedLocation ensureCreateDirectory.
	backend downloadAndUnzip: aZnUrl at: expectedLocation.
	expectedLocation children
		select: [ :c | #(image changes) includes: c extension ]
		thenDo: [ :child | child renameTo: 'Pharo.' , child extension ]
]

{ #category : #'image calls' }
TKTFileOrientedDeployer >> resolveCurrentImageAnChangesFile [
	(self currentCacheFolder / 'Pharo.image') ensureDelete.
	(self currentCacheFolder / 'Pharo.changes') ensureDelete.
	self currentCacheFolder ensureCreateDirectory.
	^ self backupCurrentImage
]

{ #category : #'deploy destination' }
TKTFileOrientedDeployer >> resolveCurrentVM [
	^ Smalltalk vmDirectory asFileReference
]

{ #category : #'image calls' }
TKTFileOrientedDeployer >> updateDeployed: aDeployed using: aDeployer [
	aDeployed archetype dependancies
		do: [ :d | provider installProject: d at: aDeployed using: aDeployer ]
]

{ #category : #folder }
TKTFileOrientedDeployer >> vmFolder [
	^ self baseFolder / #vm
]

{ #category : #working }
TKTFileOrientedDeployer >> workingDirectory [
	^ backend workingDirectory
]