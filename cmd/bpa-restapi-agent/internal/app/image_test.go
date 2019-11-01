package app

import (
  "fmt"
  "io/ioutil"
  "log"
  "os"
  "os/user"
  "path"
  "testing"

  "github.com/stretchr/testify/mock"
  "github.com/pkg/errors"

)

type mockValues struct {
  mock.Mock
}

func (m *mockValues) GetCurrentUser() (*user.User, error) {
  fmt.Println("Mocked Get User")
  args := m.Called()

  return args.Get(0).(*user.User), args.Error(1)
}

func TestGetDirPath(t *testing.T) {
  fakeUser := user.User{}
  u := &fakeUser

  myMocks := new(mockValues)

  myMocks.On("GetCurrentUser").Return(&fakeUser, nil)
  myMocks.On("GetPath", u, "", "test_image").Return("", "")

  imageClient := ImageClient{myMocks, "test_image", "test_meta"}
  _, dir, err := imageClient.GetDirPath("")
  if err != nil {
    t.Errorf("Path was incorrect, got: %q, want: %q.", dir, "some_path")
  }
}

func (m *mockValues) DBCreate(name string, key ImageKey, meta string, c Image) error{
    fmt.Println("Mocked Create image in Mongo")
    args := m.Called(name, key, meta, c)

    return args.Error(0)
}

func (m *mockValues) DBRead(name string, key ImageKey, meta string) ([]byte, error) {
    fmt.Println("Mocked Mongo DB Read Operations")
    args := m.Called(name, key, meta)

    return args.Get(0).([]byte), args.Error(1)
}

func (m *mockValues) DBUnmarshal(value []byte) (Image, error) {
    fmt.Println("Mocked Mongo DB Unmarshal Operation")
    args := m.Called(value)

    return args.Get(0).(Image), args.Error(1)
}

func (m *mockValues) GetPath(u *user.User, imageName string, storeName string) (string, string) {
    args := m.Called(u, "", "test_image")

    return args.String(0), args.String(1)
}

func (m *mockValues) DBDelete(name string, key ImageKey, meta string) error {
    fmt.Println("Mocked Mongo DB Delete")
    args := m.Called(name, key, meta)

    return args.Error(0)

}

func (m *mockValues) DBUpdate(s string, k ImageKey, t string, c Image) error {
    fmt.Println("Mocked Mongo DB Update")
    args := m.Called(s, k, t, c)

    return args.Error(0)
}

func TestCreate(t *testing.T) {
    dir, err := ioutil.TempDir("", "test_images")
    if err != nil {
        log.Fatal(err)
    }
    defer os.RemoveAll(dir)

    image := Image{
                    ImageName: "test_asdf",
                }
    arr_data := []byte{}
    key := ImageKey{ImageName:"test_asdf"}
    myMocks := new(mockValues)
    // just to get an error value
    err1 := errors.New("math: square root of negative number")

    fakeUser := user.User{}
    u := &fakeUser
    file_path := path.Join(dir, "test_asdf")

    myMocks.On("DBCreate", "test_image", key, "test_meta", image).Return(nil)
    myMocks.On("DBRead", "test_image", key, "test_meta").Return(arr_data, err1)
    myMocks.On("DBUnmarshal", arr_data).Return(image, nil)
    myMocks.On("GetCurrentUser").Return(&fakeUser, nil)
    myMocks.On("GetPath", u, "", "test_image").Return(file_path, dir)

    imageClient := ImageClient{myMocks, "test_image", "test_meta"}
    _, err = imageClient.Create(image)
    if err != nil {
        t.Errorf("Some error occured!")
    }
}

func TestDelete(t *testing.T) {
    tmpfile, err := ioutil.TempFile("", "test_images")
    if err != nil {
        log.Fatal(err)
    }
    defer os.Remove(tmpfile.Name())

    key := ImageKey{ImageName: "test_asdf"}
    fakeUser := user.User{}
    u := &fakeUser
    file_path := tmpfile.Name()

    myMocks := new(mockValues)

    myMocks.On("DBDelete", "test_image", key, "test_meta").Return(nil)
    myMocks.On("GetCurrentUser").Return(&fakeUser, nil)
    myMocks.On("GetPath", u, "", "test_image").Return(file_path, "")

    imageClient := ImageClient{myMocks, "test_image", "test_meta"}
    err = imageClient.Delete("test_asdf")
    if err != nil {
        t.Errorf("Some error occured!")
    }

}

func TestUpdate(t *testing.T) {
    image := Image{}
    key := ImageKey{}
    arr_data := []byte{} 

    myMocks := new(mockValues)

    myMocks.On("DBRead", "test_image", key, "test_meta").Return(arr_data, nil)
    myMocks.On("DBUnmarshal", arr_data).Return(image, nil)
    myMocks.On("DBUpdate", "test_image", key, "test_meta", image).Return(nil)
    imageClient := ImageClient{myMocks, "test_image", "test_meta"}
    _, err := imageClient.Update("", image)
    if err != nil {
        t.Errorf("Some error occured!")
    }
}
