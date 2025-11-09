package main

import (
	"context"
	"dagger/terraform-image/internal/dagger"
	"fmt"
	"strings"
)

type TerraformImage struct{}

func CosignSignImage(
	ctx context.Context,
	harborAddr string,
	robotUsername string,
	robotToken *dagger.Secret,
	imageDigest string,
	cosignKey *dagger.Secret,
	cosignPass *dagger.Secret,
) (string, error) {
	token, err := robotToken.Plaintext(ctx)
	if err != nil {
		return "", err
	}

	return dag.Container().
		From("ghcr.io/sigstore/cosign/cosign:latest").
		WithMountedSecret(
			"/cosign.key",
			cosignKey,
			dagger.ContainerWithMountedSecretOpts{Owner: "root", Mode: 0444},
		).
		WithSecretVariable("COSIGN_PASSWORD", cosignPass).
		// Login via stdin because there are 0 binaries in this container
		// Cannot use "sh -c cosign sign ... --registry-password $ROBOT_TOKEN" for example
		WithExec(
			[]string{
				"cosign", "login",
				harborAddr,
				"--username", robotUsername,
				"--password-stdin",
			},
			dagger.ContainerWithExecOpts{
				Stdin: token,
			},
		).
		WithExec([]string{
			"cosign", "sign",
			"--key", "/cosign.key",
			"--recursive",
			"--yes",
			imageDigest,
		}).
		Stdout(ctx)
}

func (m *TerraformImage) Build(
	ctx context.Context,
	src *dagger.Directory,
	harborRobotToken *dagger.Secret,
	harborAddr string,
	cosignKey *dagger.Secret,
	cosignPass *dagger.Secret,
	terraformVer string,
) (string, error) {
	imgRef := "harbor.okwilkins.dev/main/terraform"

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
			{
				Name:  "TERRAFORM_VER",
				Value: terraformVer,
			},
		}
		buildOpts := dagger.DirectoryDockerBuildOpts{Platform: platform, BuildArgs: buildArgs}
		ctr := src.DockerBuild(buildOpts)
		platformVariants = append(platformVariants, ctr)
	}

	digest, err := dag.Container().
		WithRegistryAuth(harborAddr, "robot$main+dagger", harborRobotToken).
		Publish(
			ctx,
			fmt.Sprintf("%s:%s", imgRef, terraformVer),
			dagger.ContainerPublishOpts{PlatformVariants: platformVariants},
		)

	if err != nil {
		return "", err
	}

	_, err = CosignSignImage(
		ctx,
		"harbor.okwilkins.dev",
		`robot$main+dagger`,
		harborRobotToken,
		digest,
		cosignKey,
		cosignPass,
	)

	if err != nil {
		return "", err
	}

	return digest, nil
}
