package main

import (
	"context"
	"fmt"
	"strings"

	"dagger/coredns/internal/dagger"
)

type Coredns struct{}

// Build and push image from existing Dockerfile
func (m *Coredns) Build(ctx context.Context, src *dagger.Directory) (string, error) {
	var platforms = []dagger.Platform{
		"linux/amd64",
		"linux/arm64",
	}
	platformVariants := make([]*dagger.Container, 0, len(platforms))

	for _, platform := range platforms {
		platformParts := strings.Split(string(platform), "/")
		if len(platformParts) != 2 {
			return "", fmt.Errorf("invalid platform format: %s", platform)
		}
		platformOs := platformParts[0]
		platformArch := platformParts[1]

		buildArgs := []dagger.BuildArg{
			{
				Name:  "GOARCH",
				Value: platformArch,
			},
			{
				Name:  "GOOS",
				Value: platformOs,
			},
		}
		buildOpts := dagger.DirectoryDockerBuildOpts{Platform: platform, BuildArgs: buildArgs}
		ctr := src.DockerBuild(buildOpts)
		platformVariants = append(platformVariants, ctr)
	}

	imageDigest, err := dag.Container().
		Publish(ctx, "ttl.sh/coredns:1h", dagger.ContainerPublishOpts{
			PlatformVariants: platformVariants,
		})

	if err != nil {
		return "", err
	}

	return imageDigest, nil
}
