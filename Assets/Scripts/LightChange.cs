using UnityEngine;

public class LightChange : MonoBehaviour
{
    public float cycleSpeed = 1f;          // How fast the colors change
    public Material targetMaterial;        // Assign the material you want to update

    private Light lightComponent;

    void Awake()
    {
        lightComponent = GetComponent<Light>();
        if (targetMaterial == null)
        {
            Debug.LogWarning("No material assigned to RainbowLightWithMaterial!");
        }
    }

    void Update()
    {
        // Cycle through hue over time
        float hue = Mathf.Repeat(Time.time * cycleSpeed, 1f);
        Color rainbowColor = Color.HSVToRGB(hue, 1f, 1f);

        // Update the light color
        lightComponent.color = rainbowColor;

        // Update the material color
        if (targetMaterial != null)
        {
            // Base color (albedo)
            targetMaterial.SetColor("_BaseColor", rainbowColor);

            // Emission color (make sure emission is enabled in material)
            targetMaterial.SetColor("_EmissionColor", rainbowColor * 15);
        }
    }
}
