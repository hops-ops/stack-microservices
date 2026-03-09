
import models.ai.com.ops.hops.v1alpha1 as stacksv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.dev.meta.v2alpha1 as metav2alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1


_items = [
    metav1alpha1.CompositionTest{
        metadata.name: ""
        spec= {
            assertResources: []
            compositionPath: "apis/knativestacks/composition.yaml"
            xrPath: ""
            xrdPath: "apis/knativestacks/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
]
items= _items