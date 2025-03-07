# Roadmap

## Next
- scheduling tools 🛠️
- abstraction for conscutive, dependant calls
- tooling for timeseries generation
- tooling for inter-actor communication
- automatically store last action in actor

- reintroduce actor config into the mix

- alter simulation population at runtime
  - add
  - remove
  - replace
  - manual actions
  - store and restore actor state <--------------------- crucial for self healing

- ws add connection to log metadata
- limit run duration
- explicit start/default delay (ramp up)

## Fix
- quest url from config
- rationalize type signatures for large tuples (convert to maps?)
  - action executor
  - behavior registry/behavior spec?
- make actor supervisor self healing? (what about state?)

## Feature ideas
- serve more detailed statistics from db
- save/restore state!!! (ugh) <- the actors restarting is pointless without this
- python behaviours
- fuzzer (fuzzy actor example?)
- action replay?
- restore state from target
- add new behaviours at runtime
- configure simulations at runtime
  - extract behavior creation to lab

## Improvements
- document/enforce simulation folder/namespacing
- tests
- uniform error handling
~~- dashboard: better terminal renderer~~

## Just thinking
- find a controlled way to handle behavior loading?
- remove behavior registry altogether?ß
- rename behavior to personality to avoid confusion with elixir's behaviour keyword
- simple connectors?
  - rest?
  - ws?
  - pg?
  - Opensearch?

## Done
- actor supervisor should be in charge of scheduling actor starts (so it does when it crashes) ✅
- multi-tenant todo example ✅
- find a way to store runtime config along with simulation ✅
- actor/behavior states ✅
- add stats to ui (actions per second?) ✅
- inject correct ws url ✅
- use serial id as identifier in UI instead of name ✅
- use message specific functions in ws handler ✅
- batch sizes in config ✅
- optimize actor overview ✅
- show that actor is acting ✅
- newly created actors don't show up in ui (create event) ✅
- action count ✅
- write in batch on action logger ✅
- normalize wait times to "simulation time" instead of ticks ✅
- action log should include failed requests ✅
- can I have the same port for ws and http? ✅
- graphic dashboard ✅
- make actors restart after process dies ✅
- refactor questdb writer ✅
- behaviors in dashboard are broken ✅
- actor complaint ✅
- rename project to beamulator ✅
- switch to self-scheduling actors ✅
- inject actor data in logger ✅
- store uuid before setting random seed ✅
- stagger actor starts ✅
- verify message queueing ✅
- monitor actor internals (ie mailbox) ✅
- single source for example/simulation path ✅
- better logging ✅
- query actors tool + example ✅
- destroy actors tool + example ✅
- spawn actors at runtime ✅
- monitor application (dashboard) ✅
- action logger on db ✅
- simplify action execution with a macro ✅
