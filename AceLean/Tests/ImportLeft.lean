module

import AceLean

-- Independent lexicons can register the same phrase; combining them must fail.
ace_adjective "contested" := fun n : Nat => n = 0
