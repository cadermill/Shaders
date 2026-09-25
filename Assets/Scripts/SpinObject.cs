using UnityEngine;

public class SpinObject : MonoBehaviour
{
    void Update()
    {
        transform.Rotate(Vector3.up, 10f * Time.deltaTime);
        transform.Rotate(Vector3.right, 10f * Time.deltaTime);
    }
}
