## **Required Assets (add to Assets.xcassets)**





These are **suggested names** — keep them consistent.





### **Mandatory (for now)**





- pin_bottle_active
- pin_bottle_locked
- pin_bottle_expired







### **Optional / Future-Ready**





- pin_bottle_premium
- pin_bottle_event







### **Asset guidelines**





- Size: **64×64 px** (will be downscaled)
- Transparent background (PNG or PDF)
- Centered anchor point (tip of pin at bottom center)
- Avoid fine details (pins are small)





------





## **Why this design is correct**





- **ViewModel exists**, but:

  

  - UI-only
  - cheap
  - disposable

  

- **No business logic leakage**

- **Pin styles are declarative**

- **Adding a new style = add one enum case + asset**

- **Works with clustering and future MapKit changes**

- **Safe for hundreds of pins**