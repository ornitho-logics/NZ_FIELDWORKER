



### Decision Rules for ToDo-s (TODO!)

#### CATCHING

* Only attempt capture if estimated days to hatch (`min_days_to_hatch`) is **14 or fewer**
* Do **not** attempt capture if `nest_state` is **'H' (hatched)**
* Allow a **minimum one-day break** between capture attempts at the same nest
* Capture only if **hatching hasn't started**: `hatch_state` must **not** contain **S, C, or CC**

#### NEST CHECKS

* Check the nest if the **last visit was 7 or more days ago**
* Prioritize checks if `nest_state` is **'pD' (possibly deserted)** or **'pP' (possibly predated)**

#### HATCH CHECKS

* Check the nest if `min_days_to_hatch` is **4 or fewer days**
* If there are no visible signs of hatching and the nest was checked today, wait **two days** before the next check (instead of checking daily).
* If **not all chicks have hatched**, check again (based on `hatch_state`, `brood_size`, and `clutch_size`)
