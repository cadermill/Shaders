using UnityEngine;

public class Spin : MonoBehaviour
{
    public float rotationSpeed = 45f;  // degrees per second

    void Update()
    {
        transform.Rotate(0f, rotationSpeed * Time.deltaTime, 0f);
    }
}
