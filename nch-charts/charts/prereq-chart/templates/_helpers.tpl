{{- define "helmchart.namespace" -}}
{{ default .Release.Namespace .Values.global.namespaceOverride }}
{{- end -}}

{{- define "imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"username\": \"%s\", \"password\": \"%s\", \"auth\": \"%s\"}}}" .Values.global.imageRegistry.server .Values.global.imageRegistry.username .Values.global.imageRegistry.password (printf "%s:%s" .Values.global.imageRegistry.username .Values.global.imageRegistry.password | b64enc) | b64enc }}
{{- end }}
